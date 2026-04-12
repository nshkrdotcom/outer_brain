defmodule OuterBrain.Core.ActionRequestCompilerTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.{RuntimeFact, ToolManifestSnapshot}
  alias OuterBrain.Core.{ActionRequestCompiler, RuntimeFactNormalizer, SemanticFrame}

  test "compiler validates against the stored manifest snapshot before dispatch" do
    frame = SemanticFrame.seed("session_alpha", "reply to the user")

    assert {:ok, snapshot} =
             ToolManifestSnapshot.new(%{
               manifest_id: "manifest_1",
               version: "1",
               schema_hash: "schema_1",
               compiled_at: DateTime.from_unix!(1_800_000_300),
               routes: %{
                 "reply_to_user" => %{
                   description: "Reply to the user",
                   input_schema_hash: "schema_reply"
                 }
               }
             })

    assert {:ok, request} =
             ActionRequestCompiler.compile(
               frame,
               snapshot,
               %{
                 request_id: "request_1",
                 manifest_id: "manifest_1",
                 schema_hash: "schema_1",
                 route: "reply_to_user",
                 args: %{"tone" => "brief"},
                 provenance: %{turn_id: "turn_1"}
               },
               0.9
             )

    assert request.route == "reply_to_user"

    assert {:error, :stale_manifest} =
             ActionRequestCompiler.compile(
               frame,
               snapshot,
               %{
                 manifest_id: "manifest_0",
                 schema_hash: "schema_1",
                 route: "reply_to_user"
               },
               0.9
             )

    assert {:error, :clarification_required} =
             ActionRequestCompiler.compile(
               frame,
               snapshot,
               %{
                 manifest_id: "manifest_1",
                 schema_hash: "schema_1",
                 route: "reply_to_user"
               },
               0.2
             )
  end

  test "runtime facts normalize to exactly one wake path" do
    assert {:ok, fact} =
             RuntimeFact.new(%{
               fact_id: "fact_1",
               kind: :publication_failed,
               causal_unit_id: "causal_1",
               payload: %{publication_id: "publication_1"}
             })

    assert %{wake_path: :repair_publication, fact_id: "fact_1"} =
             RuntimeFactNormalizer.normalize(fact)
  end
end
