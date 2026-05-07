defmodule OuterBrain.Prompting.PromptPackTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.ToolManifestSnapshot
  alias OuterBrain.Core.SemanticFrame
  alias OuterBrain.Prompting.{ContextPack, PromptPack, StrategyProfile, ToolGate}

  test "prompt packs keep stable refs and quality inputs replay-explainable" do
    frame =
      "session_alpha"
      |> SemanticFrame.seed("answer the user")
      |> SemanticFrame.record_commitment("I will confirm the route")

    assert {:ok, snapshot} =
             ToolManifestSnapshot.new(%{
               manifest_id: "manifest_1",
               version: "1",
               schema_hash: "schema_1",
               compiled_at: DateTime.from_unix!(1_800_000_400),
               routes: %{
                 "reply_to_user" => %{
                   description: "Reply to the user",
                   input_schema_hash: "schema_reply"
                 }
               }
             })

    context_pack = ContextPack.build(frame, ["turn_1", "artifact_1"], mode: :reply)

    assert {:ok, pack} = PromptPack.build(context_pack, snapshot, :balanced)
    assert pack.context.refs == ["turn_1", "artifact_1"]
    assert pack.tools == ["reply_to_user"]

    assert pack.persistence_posture.persistence_profile_ref ==
             "persistence-profile://mickey-mouse"

    assert pack.persistence_posture.raw_prompt_persistence? == false
    assert {:ok, %{name: :balanced}} = StrategyProfile.fetch(:balanced)
  end

  test "manifest invalidation is caught before dispatch" do
    assert {:ok, snapshot} =
             ToolManifestSnapshot.new(%{
               manifest_id: "manifest_1",
               version: "1",
               schema_hash: "schema_1",
               compiled_at: DateTime.from_unix!(1_800_000_401),
               routes: %{
                 "reply_to_user" => %{
                   description: "Reply to the user",
                   input_schema_hash: "schema_reply"
                 }
               }
             })

    assert {:error, :stale_manifest} ==
             ToolGate.validate(snapshot, %{
               manifest_id: "manifest_0",
               schema_hash: "schema_1",
               route: "reply_to_user"
             })
  end
end
