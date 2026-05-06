defmodule OuterBrain.WorkspaceTest do
  use ExUnit.Case, async: true

  Code.require_file("build_support/weld.exs", File.cwd!())

  alias OuterBrain.Build.WeldContract
  alias OuterBrain.Build.WorkspaceContract
  alias OuterBrain.Workspace
  alias OuterBrain.Workspace.MixProject

  test "lists workspace packages" do
    assert "core/outer_brain_contracts" in Workspace.package_paths()
    assert "core/outer_brain_persistence" in Workspace.package_paths()
    assert "core/ai_artifact_contracts" in Workspace.package_paths()
    assert "core/optimization_artifact_store" in Workspace.package_paths()
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

  test "runtime workspace manifest stays aligned with build support contract" do
    Code.require_file("build_support/workspace_contract.exs", File.cwd!())

    assert Workspace.package_paths() == WorkspaceContract.package_paths()
    assert Workspace.active_project_globs() == WorkspaceContract.active_project_globs()
  end

  test "uses the released Weld 0.7.2 line directly" do
    assert {:weld, "~> 0.7.2", runtime: false} in MixProject.project()[:deps]
  end

  test "uses Weld task autodiscovery instead of local release aliases" do
    aliases = MixProject.project()[:aliases]

    refute Keyword.has_key?(aliases, :"weld.release.prepare")
    refute Keyword.has_key?(aliases, :"weld.release.track")
    refute Keyword.has_key?(aliases, :"weld.release.archive")
    refute Keyword.has_key?(aliases, :"release.prepare")
    refute Keyword.has_key?(aliases, :"release.track")
    refute Keyword.has_key?(aliases, :"release.archive")
  end

  test "weld projection docs main points at generated root README page" do
    assert WeldContract.artifact()[:package][:docs_main] == "readme-1"
  end

  test "child packages do not hard-code sibling repo paths" do
    refute String.contains?(File.read!("bridges/domain_bridge/mix.exs"), "/home/home/p/g/n/")
  end
end
