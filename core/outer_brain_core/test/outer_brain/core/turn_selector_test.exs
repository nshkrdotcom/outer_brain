defmodule OuterBrain.Core.TurnSelectorTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.ToolManifestSnapshot
  alias OuterBrain.Core.TurnSelector

  test "selects compile_workspace when the turn targets the workspace" do
    assert {:ok, snapshot} =
             ToolManifestSnapshot.new(%{
               manifest_id: "manifest_workspace",
               version: "1",
               schema_hash: "schema_workspace",
               compiled_at: DateTime.from_unix!(1_800_002_100),
               routes: %{
                 "compile_workspace" => %{
                   description: "Compile the workspace",
                   input_schema_hash: "schema_compile_workspace",
                   examples: [%{workspace_id: "workspace/main"}]
                 }
               }
             })

    assert {:ok, selection, confidence} =
             TurnSelector.select(
               snapshot,
               "compile the workspace",
               request_id: "semantic-turn-1",
               scope_id: "workspace/main"
             )

    assert selection.route == "compile_workspace"
    assert selection.args.workspace_id == "workspace/main"
    assert confidence == 0.92
  end

  test "requires clarification when multiple routes are present without a match" do
    assert {:ok, snapshot} =
             ToolManifestSnapshot.new(%{
               manifest_id: "manifest_multi",
               version: "1",
               schema_hash: "schema_multi",
               compiled_at: DateTime.from_unix!(1_800_002_101),
               routes: %{
                 "compile_workspace" => %{
                   description: "Compile the workspace",
                   input_schema_hash: "schema_compile_workspace",
                   examples: [%{workspace_id: "workspace/main"}]
                 },
                 "reply_to_user" => %{
                   description: "Reply to the user",
                   input_schema_hash: "schema_reply",
                   examples: [%{body: "hello"}]
                 }
               }
             })

    assert {:error, :clarification_required} =
             TurnSelector.select(
               snapshot,
               "do something later",
               request_id: "semantic-turn-2",
               scope_id: "workspace/main"
             )
  end
end
