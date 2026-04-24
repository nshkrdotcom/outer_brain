defmodule OuterBrain.Runtime.MemoryInvalidationConsumer do
  @moduledoc """
  Applies cluster and durable memory invalidations to runtime-owned caches.
  """

  @ordering_fields [:source_node_ref, :commit_lsn, :commit_hlc]

  @spec apply_cluster_message(map(), keyword()) :: {:ok, map()} | {:error, term()}
  def apply_cluster_message(message, callbacks) when is_map(message) and is_list(callbacks) do
    with {:ok, invalidation} <- invalidation_from_cluster_message(message),
         {:ok, recall_result} <- call(callbacks, :recall_cache_invalidate, [invalidation]),
         {:ok, sidecar_result} <- call(callbacks, :sidecar_index_invalidate, [invalidation]) do
      {:ok,
       %{
         recall_cache_evictions: evicted_entries(recall_result),
         sidecar_index_evictions: evicted_entries(sidecar_result)
       }}
    end
  end

  @spec reconcile_from_durable(keyword(), keyword()) :: {:ok, map()} | {:error, term()}
  def reconcile_from_durable(callbacks, opts)
      when is_list(callbacks) and is_list(opts) do
    with {:ok, rows} <- call(callbacks, :durable_invalidation_rows, [opts]),
         true <- is_list(rows) do
      apply_rows(rows, callbacks)
    else
      false -> {:error, :invalid_durable_invalidation_rows}
      {:error, reason} -> {:error, reason}
    end
  end

  defp apply_rows(rows, callbacks) do
    Enum.reduce_while(
      rows,
      {:ok, %{rows_seen: 0, recall_cache_evictions: 0, sidecar_index_evictions: 0}},
      fn
        row, {:ok, acc} ->
          with {:ok, invalidation} <- normalize_invalidation(row),
               {:ok, recall_result} <- call(callbacks, :recall_cache_invalidate, [invalidation]),
               {:ok, sidecar_result} <- call(callbacks, :sidecar_index_invalidate, [invalidation]) do
            {:cont,
             {:ok,
              %{
                rows_seen: acc.rows_seen + 1,
                recall_cache_evictions:
                  acc.recall_cache_evictions + evicted_entries(recall_result),
                sidecar_index_evictions:
                  acc.sidecar_index_evictions + evicted_entries(sidecar_result)
              }}}
          else
            {:error, reason} -> {:halt, {:error, reason}}
          end
      end
    )
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
         commit_hlc: fetch_value(source, :commit_hlc),
         parent_chain: fetch_value(source, :parent_chain) || []
       }}
    else
      {:error, reason} -> {:error, reason}
      _other -> {:error, :invalid_memory_invalidation}
    end
  end

  defp require_ordering(source) do
    case Enum.find(@ordering_fields, &(fetch_value(source, &1) == nil)) do
      nil -> :ok
      field -> {:error, {:missing_ordering_evidence, field}}
    end
  end

  defp call(callbacks, key, args) do
    case Keyword.get(callbacks, key) do
      fun when is_function(fun, length(args)) -> apply(fun, args)
      nil -> {:error, {:missing_callback, key}}
      _other -> {:error, {:invalid_callback, key}}
    end
  end

  defp evicted_entries(%{evicted_entries: count}) when is_integer(count), do: count
  defp evicted_entries(%{"evicted_entries" => count}) when is_integer(count), do: count
  defp evicted_entries(_result), do: 0

  defp fetch_value(source, key) when is_map(source),
    do: Map.get(source, key) || Map.get(source, Atom.to_string(key))

  defp fetch_value(_source, _key), do: nil
end
