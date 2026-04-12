defmodule OuterBrain.Contracts.ManifestAndPublicationTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.{
    ActionRequest,
    ReplyPublication,
    RuntimeFact,
    ToolManifestSnapshot
  }

  test "manifest snapshots validate selections and keep provisional replies distinct" do
    assert {:ok, snapshot} =
             ToolManifestSnapshot.new(%{
               manifest_id: "manifest_1",
               version: "1",
               schema_hash: "schema_1",
               compiled_at: DateTime.from_unix!(1_800_000_100),
               routes: %{
                 "reply_to_user" => %{
                   description: "Reply to the user",
                   input_schema_hash: "schema_reply"
                 }
               }
             })

    assert :ok ==
             ToolManifestSnapshot.selection_valid?(snapshot, %{
               manifest_id: "manifest_1",
               schema_hash: "schema_1",
               route: "reply_to_user"
             })

    assert {:error, :stale_manifest} ==
             ToolManifestSnapshot.selection_valid?(snapshot, %{
               manifest_id: "manifest_0",
               schema_hash: "schema_1",
               route: "reply_to_user"
             })

    assert {:ok, request} =
             ActionRequest.new(%{
               request_id: "request_1",
               session_id: "session_alpha",
               manifest_id: "manifest_1",
               route: "reply_to_user",
               args: %{"body" => "hello"},
               provenance: %{turn_id: "turn_1"}
             })

    assert request.route == "reply_to_user"

    assert {:ok, provisional} =
             ReplyPublication.new(%{
               publication_id: "publication_1",
               causal_unit_id: "causal_1",
               phase: :provisional,
               dedupe_key: "reply:provisional",
               state: :published,
               body: "Working on it"
             })

    assert {:ok, final} =
             ReplyPublication.new(%{
               publication_id: "publication_2",
               causal_unit_id: "causal_1",
               phase: :final,
               dedupe_key: "reply:final",
               state: :published,
               body: "Done"
             })

    assert provisional.phase != final.phase

    assert {:ok, fact} =
             RuntimeFact.new(%{
               fact_id: "fact_1",
               kind: :execution_completed,
               causal_unit_id: "causal_1",
               payload: %{attempt_id: "attempt_1"}
             })

    assert RuntimeFact.wake_key(fact) == "causal_1:execution_completed"
  end
end
