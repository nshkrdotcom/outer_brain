defmodule OuterBrain.Workspace do
  @moduledoc """
  Introspection helpers for the OuterBrain workspace root.
  """

  @package_paths [
    "core/outer_brain_contracts",
    "core/outer_brain_journal",
    "core/outer_brain_persistence",
    "core/outer_brain_core",
    "core/outer_brain_prompting",
    "core/outer_brain_quality",
    "core/outer_brain_runtime",
    "core/outer_brain_authority_evidence",
    "core/outer_brain_restart_authority",
    "core/memory_contracts",
    "core/memory_engine",
    "core/context_budget",
    "core/prompt_fabric",
    "core/guardrail_contracts",
    "core/guardrail_engine",
    "bridges/domain_bridge",
    "bridges/citadel_bridge",
    "bridges/publication_bridge",
    "bridges/review_bridge",
    "bridges/ground_plane_projection_bridge",
    "apps/host_surface",
    "examples/console_chat",
    "examples/direct_citadel_action"
  ]

  @active_project_globs [".", "core/*", "bridges/*", "apps/*", "examples/*"]

  @spec package_paths() :: [String.t()]
  def package_paths do
    @package_paths
  end

  @spec active_project_globs() :: [String.t()]
  def active_project_globs do
    @active_project_globs
  end
end
