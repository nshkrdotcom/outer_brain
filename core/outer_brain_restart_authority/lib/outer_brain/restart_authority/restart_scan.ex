defmodule OuterBrain.RestartAuthority.RestartScan do
  @moduledoc """
  Reconstructs lawful next action from journal state alone.
  """

  alias OuterBrain.Journal

  @spec reconstruct(Journal.state(), String.t(), String.t()) :: map()
  def reconstruct(state, session_id, causal_unit_id)
      when is_binary(session_id) and is_binary(causal_unit_id) do
    pending_tasks = Journal.pending_recovery_tasks(state, session_id)
    publication_phase = Journal.latest_publication_phase(state, causal_unit_id)

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
      pending_recovery_tasks: Enum.map(pending_tasks, & &1.reason),
      next_action: next_action
    }
  end
end
