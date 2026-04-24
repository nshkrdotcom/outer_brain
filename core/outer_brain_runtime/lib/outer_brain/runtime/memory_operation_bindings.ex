defmodule OuterBrain.Runtime.MemoryOperationBindings do
  @moduledoc """
  Validates and adapts runtime memory-operation owner callbacks.

  This keeps the runtime-facing callback names explicit while passing the
  smaller callback surface expected by `OuterBrain.Memory.RecallOrchestrator`
  and `OuterBrain.Memory.PrivateWriter`.
  """

  @recall_bindings [
    :snapshot_pin,
    :access_graph_views,
    :read_policy,
    :tier_reader,
    :transform,
    :recall_proof
  ]

  @private_write_bindings [
    :write_policy,
    :extract_candidates,
    :write_transform,
    :dedupe_private,
    :insert_private,
    :write_private_proof
  ]

  @share_up_bindings [
    :scope_registered?,
    :share_up_policy,
    :share_up_transform,
    :insert_shared,
    :share_up_proof
  ]

  @invalidation_bindings [
    :recall_cache_invalidate,
    :sidecar_index_invalidate,
    :durable_invalidation_rows
  ]

  @spec recall_callbacks(map()) :: {:ok, keyword()} | {:error, term()}
  def recall_callbacks(bindings) when is_map(bindings) do
    with :ok <- require_bindings(bindings, @recall_bindings) do
      {:ok,
       [
         snapshot_pin: fetch!(bindings, :snapshot_pin),
         access_graph_views: fetch!(bindings, :access_graph_views),
         read_policy: fetch!(bindings, :read_policy),
         tier_reader: fetch!(bindings, :tier_reader),
         transform: fetch!(bindings, :transform),
         proof_emitter: fetch!(bindings, :recall_proof)
       ]}
    end
  end

  def recall_callbacks(_bindings), do: {:error, :invalid_recall_bindings}

  @spec private_write_callbacks(map()) :: {:ok, keyword()} | {:error, term()}
  def private_write_callbacks(bindings) when is_map(bindings) do
    with :ok <- require_bindings(bindings, @private_write_bindings) do
      {:ok,
       [
         write_policy: fetch!(bindings, :write_policy),
         extract_candidates: fetch!(bindings, :extract_candidates),
         transform: fetch!(bindings, :write_transform),
         dedupe: fetch!(bindings, :dedupe_private),
         insert_private: fetch!(bindings, :insert_private),
         proof_emitter: fetch!(bindings, :write_private_proof)
       ]}
    end
  end

  def private_write_callbacks(_bindings), do: {:error, :invalid_private_write_bindings}

  @spec share_up_callbacks(map()) :: {:ok, keyword()} | {:error, term()}
  def share_up_callbacks(bindings) when is_map(bindings) do
    with :ok <- require_bindings(bindings, @share_up_bindings) do
      {:ok,
       [
         scope_registered?: fetch!(bindings, :scope_registered?),
         share_up_policy: fetch!(bindings, :share_up_policy),
         transform: fetch!(bindings, :share_up_transform),
         insert_shared: fetch!(bindings, :insert_shared),
         proof_emitter: fetch!(bindings, :share_up_proof)
       ]}
    end
  end

  def share_up_callbacks(_bindings), do: {:error, :invalid_share_up_bindings}

  @spec invalidation_callbacks(map()) :: {:ok, keyword()} | {:error, term()}
  def invalidation_callbacks(bindings) when is_map(bindings) do
    with :ok <- require_bindings(bindings, @invalidation_bindings) do
      {:ok,
       [
         recall_cache_invalidate: fetch!(bindings, :recall_cache_invalidate),
         sidecar_index_invalidate: fetch!(bindings, :sidecar_index_invalidate),
         durable_invalidation_rows: fetch!(bindings, :durable_invalidation_rows)
       ]}
    end
  end

  def invalidation_callbacks(_bindings), do: {:error, :invalid_invalidation_bindings}

  defp require_bindings(bindings, required) do
    case Enum.find(required, &(not valid_binding?(bindings, &1))) do
      nil -> :ok
      key -> {:error, {:missing_binding, key}}
    end
  end

  defp valid_binding?(bindings, key), do: is_function(fetch_value(bindings, key))

  defp fetch!(bindings, key), do: fetch_value(bindings, key)

  defp fetch_value(bindings, key),
    do: Map.get(bindings, key) || Map.get(bindings, Atom.to_string(key))
end
