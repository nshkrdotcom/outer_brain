defmodule OuterBrain.Memory.RecallCache do
  @moduledoc """
  Process-local cache for recall result references.

  The cache stores fragment identifiers and content hashes only. Memory payloads
  remain in the durable tier stores and are deliberately rejected here.
  """

  @table_name :outer_brain_recall_cache
  @key_fields [:tenant_ref, :snapshot_epoch, :tier, :query_hash]
  @ordering_fields [:source_node_ref, :commit_lsn, :commit_hlc]

  @spec new(keyword()) :: :ets.tid()
  def new(opts \\ []) when is_list(opts) do
    :ets.new(Keyword.get(opts, :name, @table_name), [:set, :private])
  end

  @spec put(:ets.tid(), map(), [map()]) :: :ok | {:error, term()}
  def put(cache, key_attrs, fragments) when is_list(fragments) do
    with {:ok, key} <- normalize_key(key_attrs),
         {:ok, fragment_refs} <- sanitize_fragment_refs(fragments) do
      entry = %{
        tenant_ref: key.tenant_ref,
        snapshot_epoch: key.snapshot_epoch,
        fragment_ids: Enum.map(fragment_refs, & &1.fragment_id),
        fragment_refs: fragment_refs
      }

      true = :ets.insert(cache, {cache_tuple(key), entry})
      :ok
    end
  end

  @spec fetch(:ets.tid(), map()) :: {:ok, [map()]} | :miss | {:error, term()}
  def fetch(cache, key_attrs) do
    with {:ok, key} <- normalize_key(key_attrs) do
      case :ets.lookup(cache, cache_tuple(key)) do
        [{_key, entry}] -> {:ok, entry.fragment_refs}
        [] -> :miss
      end
    end
  end

  @spec invalidate(:ets.tid(), map()) :: {:ok, %{evicted_entries: non_neg_integer()}}
  def invalidate(cache, invalidation) do
    {:ok, normalized} = normalize_invalidation(invalidation)
    {:ok, %{evicted_entries: evict_matching(cache, normalized)}}
  end

  @spec apply_cluster_invalidation(:ets.tid(), map()) ::
          {:ok, %{evicted_entries: non_neg_integer()}} | {:error, term()}
  def apply_cluster_invalidation(cache, message) do
    with {:ok, invalidation} <- invalidation_from_cluster_message(message) do
      invalidate(cache, invalidation)
    end
  end

  @spec reconcile(:ets.tid(), [map()]) :: {:ok, %{evicted_entries: non_neg_integer()}}
  def reconcile(cache, invalidation_rows) when is_list(invalidation_rows) do
    evicted =
      Enum.reduce(invalidation_rows, 0, fn row, acc ->
        {:ok, normalized} = normalize_invalidation(row)
        acc + evict_matching(cache, normalized)
      end)

    {:ok, %{evicted_entries: evicted}}
  end

  defp normalize_key(attrs) when is_map(attrs) do
    case Enum.find(@key_fields, &(fetch_value(attrs, &1) == nil)) do
      nil ->
        {:ok,
         %{
           tenant_ref: fetch_value(attrs, :tenant_ref),
           snapshot_epoch: fetch_value(attrs, :snapshot_epoch),
           tier: fetch_value(attrs, :tier),
           query_hash: fetch_value(attrs, :query_hash)
         }}

      field ->
        {:error, {:missing_cache_key, field}}
    end
  end

  defp cache_tuple(key), do: {key.tenant_ref, key.snapshot_epoch, key.tier, key.query_hash}

  defp sanitize_fragment_refs(fragments) do
    Enum.reduce_while(fragments, {:ok, []}, fn fragment, {:ok, acc} ->
      case sanitize_fragment_ref(fragment) do
        {:ok, ref} -> {:cont, {:ok, [ref | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, refs} -> {:ok, Enum.reverse(refs)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp sanitize_fragment_ref(fragment) when is_map(fragment) do
    cond do
      has_payload?(fragment, :content) ->
        {:error, {:unsafe_cache_payload, :content}}

      has_payload?(fragment, :body) ->
        {:error, {:unsafe_cache_payload, :body}}

      is_nil(fetch_value(fragment, :fragment_id)) ->
        {:error, {:missing_fragment_ref, :fragment_id}}

      true ->
        {:ok,
         %{
           fragment_id: fetch_value(fragment, :fragment_id),
           content_hash: fetch_value(fragment, :content_hash),
           tier: fetch_value(fragment, :tier)
         }}
    end
  end

  defp invalidation_from_cluster_message(message) do
    metadata = fetch_value(message, :metadata) || %{}

    invalidation =
      Map.merge(metadata, %{
        "tenant_ref" => fetch_value(message, :tenant_ref) || fetch_value(metadata, :tenant_ref),
        "source_node_ref" => fetch_value(message, :source_node_ref),
        "commit_lsn" => fetch_value(message, :commit_lsn),
        "commit_hlc" => fetch_value(message, :commit_hlc)
      })

    normalize_invalidation(invalidation)
  end

  defp normalize_invalidation(source) when is_map(source) do
    with :ok <- require_ordering(source),
         tenant_ref when is_binary(tenant_ref) <- fetch_value(source, :tenant_ref),
         fragment_id when is_binary(fragment_id) <- fetch_value(source, :fragment_id),
         effective_at_epoch when is_integer(effective_at_epoch) <-
           fetch_value(source, :effective_at_epoch) do
      {:ok,
       %{
         tenant_ref: tenant_ref,
         fragment_id: fragment_id,
         effective_at_epoch: effective_at_epoch,
         source_node_ref: fetch_value(source, :source_node_ref),
         commit_lsn: fetch_value(source, :commit_lsn),
         commit_hlc: fetch_value(source, :commit_hlc)
       }}
    else
      nil -> {:error, :invalid_invalidation}
      _other -> {:error, :invalid_invalidation}
    end
  end

  defp require_ordering(source) do
    case Enum.find(@ordering_fields, &(fetch_value(source, &1) == nil)) do
      nil -> :ok
      field -> {:error, {:missing_ordering_evidence, field}}
    end
  end

  defp evict_matching(cache, invalidation) do
    cache
    |> :ets.tab2list()
    |> Enum.reduce(0, fn {key, entry}, evicted ->
      if entry.tenant_ref == invalidation.tenant_ref and
           entry.snapshot_epoch >= invalidation.effective_at_epoch and
           invalidation.fragment_id in entry.fragment_ids do
        :ets.delete(cache, key)
        evicted + 1
      else
        evicted
      end
    end)
  end

  defp has_payload?(source, key),
    do: Map.has_key?(source, key) or Map.has_key?(source, Atom.to_string(key))

  defp fetch_value(source, key) when is_map(source),
    do: Map.get(source, key) || Map.get(source, Atom.to_string(key))

  defp fetch_value(_source, _key), do: nil
end
