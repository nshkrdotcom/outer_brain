defmodule OuterBrain.RestartAuthority.RestartScanTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Journal.Tables.{RecoveryTaskRecord, ReplyPublicationRecord}
  alias OuterBrain.RestartAuthority.{Reconcile, RestartScan}

  test "restart scan distinguishes provisional and final publication states" do
    provisional =
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

    assert %{
             publication_phase: :provisional,
             next_action: {:await_or_follow_up, :provisional_reply_published}
           } =
             RestartScan.reconstruct("session_1", "causal_1",
               store: __MODULE__.FakeRestartStore,
               store_opts: [pending_tasks: [], publications: [provisional]]
             )

    final =
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

    assert %{next_action: {:noop, :final_reply_published}} =
             RestartScan.reconstruct("session_1", "causal_1",
               store: __MODULE__.FakeRestartStore,
               store_opts: [pending_tasks: [], publications: [provisional, final]]
             )
  end

  test "restart scan prefers explicit recovery tasks when ambiguity remains" do
    task =
      ok!(
        RecoveryTaskRecord.new(%{
          task_id: "recovery_1",
          session_id: "session_1",
          reason: :ambiguous_submission,
          status: :pending
        })
      )

    analysis =
      RestartScan.reconstruct("session_1", "causal_1",
        store: __MODULE__.FakeRestartStore,
        store_opts: [pending_tasks: [task], publications: []]
      )

    assert analysis.next_action == {:reconcile, :ambiguous_submission}
    assert {:ok, :ambiguous_submission} == Reconcile.recovery_intent(analysis)
  end

  defmodule FakeRestartStore do
    @moduledoc false

    def pending_recovery_tasks(_session_id, opts), do: Keyword.get(opts, :pending_tasks, [])

    def latest_publication_phase(causal_unit_id, opts) do
      opts
      |> Keyword.get(:publications, [])
      |> Enum.filter(&(&1.causal_unit_id == causal_unit_id))
      |> Enum.map(& &1.phase)
      |> Enum.sort_by(&phase_rank/1, :desc)
      |> List.first()
    end

    defp phase_rank(:final), do: 2
    defp phase_rank(:provisional), do: 1
  end

  defp ok!({:ok, value}), do: value
end
