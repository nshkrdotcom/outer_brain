defmodule OuterBrain.WorkspaceTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Workspace
  alias OuterBrain.Workspace.MixProject

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

  test "uses the released Weld 0.7.0 line directly" do
    assert {:weld, "~> 0.7.0", runtime: false} in MixProject.project()[:deps]
  end

  test "exposes the release aliases for projection tracking" do
    aliases = MixProject.project()[:aliases]

    assert Keyword.fetch!(aliases, :"release.prepare") == ["weld.release.prepare"]
    assert Keyword.fetch!(aliases, :"release.track") == ["weld.release.track"]
    assert Keyword.fetch!(aliases, :"release.archive") == ["weld.release.archive"]
  end

  test "child packages do not hard-code sibling repo paths" do
    refute File.read!("bridges/domain_bridge/mix.exs") =~ "/home/home/p/g/n/"
  end
end
