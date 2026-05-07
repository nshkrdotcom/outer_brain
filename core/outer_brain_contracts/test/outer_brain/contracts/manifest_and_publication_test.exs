defmodule OuterBrain.Contracts.ManifestAndPublicationTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.{
    ActionRequest,
    ReplyBodyBoundary,
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

    assert {:ok, provisional_body} =
             ReplyBodyBoundary.build(
               "causal_1",
               :provisional,
               "reply:provisional",
               "Working on it"
             )

    assert {:ok, provisional} =
             ReplyPublication.new(%{
               publication_id: "publication_1",
               causal_unit_id: "causal_1",
               phase: :provisional,
               dedupe_key: "reply:provisional",
               state: :published,
               body: provisional_body.preview,
               body_ref: provisional_body.ref
             })

    assert {:ok, final_body} =
             ReplyBodyBoundary.build("causal_1", :final, "reply:final", "Done")

    assert {:ok, final} =
             ReplyPublication.new(%{
               publication_id: "publication_2",
               causal_unit_id: "causal_1",
               phase: :final,
               dedupe_key: "reply:final",
               state: :published,
               body: final_body.preview,
               body_ref: final_body.ref
             })

    assert provisional.phase != final.phase
    assert provisional.body_ref["body_hash"] == provisional_body.ref["content_hash"]
    assert final.body_ref["schema_hash_alg"] == "sha256"

    assert final.persistence_posture.persistence_profile_ref ==
             "persistence-profile://mickey-mouse"

    assert final.persistence_posture.raw_prompt_persistence? == false

    assert {:ok, fact} =
             RuntimeFact.new(%{
               fact_id: "fact_1",
               kind: :execution_completed,
               causal_unit_id: "causal_1",
               payload: %{attempt_id: "attempt_1"}
             })

    assert RuntimeFact.wake_key(fact) == "causal_1:execution_completed"
  end

  test "reply publications reject raw inline bodies without artifact refs" do
    assert {:error, :invalid_reply_publication} =
             ReplyPublication.new(%{
               publication_id: "publication_raw",
               causal_unit_id: "causal_1",
               phase: :final,
               dedupe_key: "reply:raw",
               state: :published,
               body: String.duplicate("full semantic reply ", 500)
             })
  end

  test "reply publications reject unredacted previews even with a body ref" do
    assert {:ok, reply_body} =
             ReplyBodyBoundary.build("causal_1", :final, "reply:redaction", "token=secret")

    assert {:error, :invalid_reply_publication} =
             ReplyPublication.new(%{
               publication_id: "publication_unredacted",
               causal_unit_id: "causal_1",
               phase: :final,
               dedupe_key: "reply:redaction",
               state: :published,
               body: "token=secret",
               body_ref: reply_body.ref
             })
  end

  test "reply publication durable posture preserves publication state" do
    assert {:ok, reply_body} =
             ReplyBodyBoundary.build("causal_1", :final, "reply:final", "Done")

    assert {:ok, publication} =
             ReplyPublication.new(%{
               publication_id: "publication_durable",
               causal_unit_id: "causal_1",
               phase: :final,
               dedupe_key: "reply:final",
               state: :published,
               body: reply_body.preview,
               body_ref: reply_body.ref,
               persistence_profile: :durable_redacted
             })

    assert publication.state == :published
    assert publication.persistence_posture.durable? == true
    assert publication.persistence_posture.raw_provider_payload_persistence? == false
  end

  test "reply body refs never create atoms from field strings" do
    source = File.read!("lib/outer_brain/contracts/reply_body_boundary.ex")
    forbidden_call = Enum.join(["String", "to_atom"], ".")

    refute String.contains?(source, forbidden_call)
  end
end
