defmodule OuterBrain.RestartAuthority.RestartScan do
  @moduledoc """
  Reconstructs lawful next action from durable restart-critical state.
  """

  alias OuterBrain.Contracts.ReplyBodyBoundary
  alias OuterBrain.Persistence.Store, as: PersistenceStore

  @spec reconstruct(String.t(), String.t(), keyword()) :: map()
  def reconstruct(session_id, causal_unit_id, opts \\ [])
      when is_binary(session_id) and is_binary(causal_unit_id) do
    store = Keyword.get(opts, :store, PersistenceStore)
    store_opts = Keyword.get(opts, :store_opts, [])
    pending_tasks = store.pending_recovery_tasks(session_id, store_opts)
    latest_publication = latest_publication(store, causal_unit_id, store_opts)
    publication_phase = publication_phase(store, causal_unit_id, store_opts, latest_publication)

    analysis(session_id, causal_unit_id, pending_tasks, publication_phase, latest_publication)
  end

  @spec analysis(String.t(), String.t(), [struct()], :final | :provisional | nil, struct() | nil) ::
          map()
  def analysis(
        session_id,
        causal_unit_id,
        pending_tasks,
        publication_phase,
        latest_publication \\ nil
      )
      when is_binary(session_id) and is_binary(causal_unit_id) and is_list(pending_tasks) do
    next_action =
      cond do
        pending_tasks != [] -> {:reconcile, hd(pending_tasks).reason}
        publication_phase == :final -> {:noop, :final_reply_published}
        publication_phase == :provisional -> {:await_or_follow_up, :provisional_reply_published}
        true -> {:publish_or_dispatch, :no_reply_recorded}
      end

    %{
      session_id: session_id,
      causal_unit_id: causal_unit_id,
      publication_phase: publication_phase,
      publication_ref: publication_ref(latest_publication),
      pending_recovery_tasks: Enum.map(pending_tasks, & &1.reason),
      next_action: next_action
    }
  end

  defp latest_publication(store, causal_unit_id, store_opts) do
    if function_exported?(store, :latest_publication, 2) do
      store.latest_publication(causal_unit_id, store_opts)
    end
  end

  defp publication_phase(_store, _causal_unit_id, _store_opts, %{phase: phase}), do: phase

  defp publication_phase(store, causal_unit_id, store_opts, _latest_publication) do
    store.latest_publication_phase(causal_unit_id, store_opts)
  end

  defp publication_ref(%{dedupe_key: dedupe_key, body_ref: body_ref}) do
    case ReplyBodyBoundary.ref_summary(body_ref) do
      nil -> nil
      summary -> Map.put(summary, :dedupe_key, dedupe_key)
    end
  end

  defp publication_ref(_latest_publication), do: nil
end
