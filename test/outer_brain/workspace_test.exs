defmodule OuterBrain.WorkspaceTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Workspace

  test "lists workspace packages" do
    assert "core/outer_brain_contracts" in Workspace.package_paths()
    assert "bridges/citadel_bridge" in Workspace.package_paths()
    assert "examples/console_chat" in Workspace.package_paths()
  end

  test "lists active project globs" do
    assert Workspace.active_project_globs() == [
             ".",
             "core/*",
             "bridges/*",
             "apps/*",
             "examples/*"
           ]
  end
end
