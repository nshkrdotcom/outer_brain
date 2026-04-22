defmodule OuterBrain.RestartAuthority.RestartScanTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.ReplyBodyBoundary
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
          body:
            reply_body!("causal_1", :provisional, "causal_1:provisional", "Working on it").preview,
          body_ref:
            reply_body!("causal_1", :provisional, "causal_1:provisional", "Working on it").ref
        })
      )

    assert %{
             publication_phase: :provisional,
             publication_ref: %{
               dedupe_key: "causal_1:provisional",
               body_hash: provisional_hash
             },
             next_action: {:await_or_follow_up, :provisional_reply_published}
           } =
             RestartScan.reconstruct("session_1", "causal_1",
               store: __MODULE__.FakeRestartStore,
               store_opts: [pending_tasks: [], publications: [provisional]]
             )

    assert provisional_hash == provisional.body_ref["body_hash"]

    final =
      ok!(
        ReplyPublicationRecord.new(%{
          publication_id: "publication_2",
          causal_unit_id: "causal_1",
          phase: :final,
          state: :published,
          dedupe_key: "causal_1:final",
          body: reply_body!("causal_1", :final, "causal_1:final", "Done").preview,
          body_ref: reply_body!("causal_1", :final, "causal_1:final", "Done").ref
        })
      )

    assert %{
             next_action: {:noop, :final_reply_published},
             publication_ref: %{dedupe_key: "causal_1:final"}
           } =
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

    def latest_publication(causal_unit_id, opts) do
      opts
      |> Keyword.get(:publications, [])
      |> Enum.filter(&(&1.causal_unit_id == causal_unit_id))
      |> Enum.sort_by(&phase_rank(&1.phase), :desc)
      |> List.first()
    end

    def latest_publication_phase(causal_unit_id, opts) do
      case latest_publication(causal_unit_id, opts) do
        nil -> nil
        publication -> publication.phase
      end
    end

    defp phase_rank(:final), do: 2
    defp phase_rank(:provisional), do: 1
  end

  defp ok!({:ok, value}), do: value

  defp reply_body!(causal_unit_id, phase, dedupe_key, body) do
    {:ok, reply_body} = ReplyBodyBoundary.build(causal_unit_id, phase, dedupe_key, body)
    reply_body
  end
end
