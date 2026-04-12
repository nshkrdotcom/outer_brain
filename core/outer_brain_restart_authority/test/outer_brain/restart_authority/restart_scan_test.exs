defmodule OuterBrain.RestartAuthority.RestartScanTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Journal
  alias OuterBrain.Journal.Tables.{RecoveryTaskRecord, ReplyPublicationRecord}
  alias OuterBrain.RestartAuthority.{Reconcile, RestartScan}

  test "restart scan distinguishes provisional and final publication states" do
    state = Journal.new()

    {:ok, provisional_state, _} =
      Journal.transact(state, fn _current ->
        {:ok,
         [
           Journal.insert(
             :reply_publications,
             ok!(
               ReplyPublicationRecord.new(%{
                 publication_id: "publication_1",
                 causal_unit_id: "causal_1",
                 phase: :provisional,
                 state: :published,
                 dedupe_key: "causal_1:provisional",
                 body: "Working on it"
               })
             )
           )
         ], :ok}
      end)

    assert %{
             publication_phase: :provisional,
             next_action: {:await_or_follow_up, :provisional_reply_published}
           } = RestartScan.reconstruct(provisional_state, "session_1", "causal_1")

    {:ok, final_state, _} =
      Journal.transact(provisional_state, fn _current ->
        {:ok,
         [
           Journal.insert(
             :reply_publications,
             ok!(
               ReplyPublicationRecord.new(%{
                 publication_id: "publication_2",
                 causal_unit_id: "causal_1",
                 phase: :final,
                 state: :published,
                 dedupe_key: "causal_1:final",
                 body: "Done"
               })
             )
           )
         ], :ok}
      end)

    assert %{next_action: {:noop, :final_reply_published}} =
             RestartScan.reconstruct(final_state, "session_1", "causal_1")
  end

  test "restart scan prefers explicit recovery tasks when ambiguity remains" do
    state = Journal.new()

    {:ok, next_state, _} =
      Journal.transact(state, fn _current ->
        {:ok,
         [
           Journal.insert(
             :recovery_tasks,
             ok!(
               RecoveryTaskRecord.new(%{
                 task_id: "recovery_1",
                 session_id: "session_1",
                 reason: :ambiguous_submission,
                 status: :pending
               })
             )
           )
         ], :ok}
      end)

    analysis = RestartScan.reconstruct(next_state, "session_1", "causal_1")

    assert analysis.next_action == {:reconcile, :ambiguous_submission}
    assert {:ok, :ambiguous_submission} == Reconcile.recovery_intent(analysis)
  end

  defp ok!({:ok, value}), do: value
end
