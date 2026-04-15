defmodule OuterBrain.JournalTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Journal

  alias OuterBrain.Journal.Tables.{
    ContextPackRecord,
    RecoveryTaskRecord,
    ReplyPublicationRecord,
    SemanticFrameRecord,
    SemanticJournalEntryRecord,
    ToolManifestRecord
  }

  test "transaction groups journal rows and keeps provisional and final publications distinct" do
    state = Journal.new()

    assert {:ok, next_state, :recorded} =
             Journal.transact(state, fn _current ->
               {:ok,
                [
                  Journal.insert(
                    :semantic_frames,
                    ok!(
                      SemanticFrameRecord.new(%{
                        frame_id: "frame_1",
                        session_id: "session_1",
                        objective: "answer the user"
                      })
                    )
                  ),
                  Journal.insert(
                    :context_packs,
                    ok!(
                      ContextPackRecord.new(%{
                        context_pack_id: "pack_1",
                        session_id: "session_1",
                        refs: ["turn_1"]
                      })
                    )
                  ),
                  Journal.insert(
                    :tool_manifests,
                    ok!(
                      ToolManifestRecord.new(%{
                        manifest_id: "manifest_1",
                        session_id: "session_1",
                        schema_hash: "schema_1",
                        version: "1",
                        compiled_at: DateTime.from_unix!(1_800_000_200),
                        routes: %{
                          "reply" => %{description: "Reply", input_schema_hash: "schema_reply"}
                        }
                      })
                    )
                  ),
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
                  ),
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
                ], :recorded}
             end)

    assert {:ok, _frame} = Journal.fetch(next_state, :semantic_frames, "frame_1")
    assert Journal.latest_publication_phase(next_state, "causal_1") == :final
  end

  test "recovery tasks remain queryable from durable journal state" do
    state = Journal.new()

    assert {:ok, next_state, :queued} =
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
                ], :queued}
             end)

    assert [%RecoveryTaskRecord{reason: :ambiguous_submission}] =
             Journal.pending_recovery_tasks(next_state, "session_1")
  end

  test "semantic journal entries remain append-only and session-scoped" do
    state = Journal.new()

    assert {:ok, next_state, :recorded} =
             Journal.transact(state, fn _current ->
               {:ok,
                [
                  Journal.insert(
                    :semantic_journal_entries,
                    ok!(
                      SemanticJournalEntryRecord.new(%{
                        entry_id: "entry_1",
                        session_id: "session_1",
                        causal_unit_id: "causal_1",
                        entry_type: "wake_input",
                        recorded_at: DateTime.from_unix!(1_800_000_300),
                        payload: %{"turn_id" => "turn_1"}
                      })
                    )
                  )
                ], :recorded}
             end)

    assert {:ok, %SemanticJournalEntryRecord{entry_type: "wake_input"}} =
             Journal.fetch(next_state, :semantic_journal_entries, "entry_1")

    assert [%SemanticJournalEntryRecord{entry_id: "entry_1"}] =
             Journal.all(next_state, :semantic_journal_entries)
  end

  defp ok!({:ok, value}), do: value
end
