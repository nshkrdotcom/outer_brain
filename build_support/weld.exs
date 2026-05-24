unless Code.ensure_loaded?(DependencySources) do
  Code.require_file("dependency_sources.exs", __DIR__)
end

Code.require_file("workspace_contract.exs", __DIR__)

defmodule OuterBrain.Build.WeldContract do
  @moduledoc false

  alias OuterBrain.Build.WorkspaceContract

  @repo_root Path.expand("..", __DIR__)

  @manifest_dependencies [
    :ground_plane_contracts,
    :jido_integration_provider_classification,
    :mezzanine_eval_engine
  ]

  @artifact_docs [
    "README.md",
    "docs/overview.md",
    "docs/layout.md",
    "docs/runtime_model.md",
    "docs/integration_surface.md",
    "core/outer_brain_authority_evidence/README.md"
  ]

  def manifest do
    [
      workspace: [
        root: "..",
        project_globs: WorkspaceContract.active_project_globs()
      ],
      classify: [
        tooling: ["."],
        proofs: ["examples/console_chat", "examples/direct_citadel_action"]
      ],
      publication: [
        internal_only: [
          ".",
          "core/context_abi",
          "core/memory_contracts",
          "core/memory_engine",
          "core/context_budget",
          "core/token_meter",
          "core/prompt_fabric",
          "core/guardrail_contracts",
          "core/guardrail_engine",
          "core/eval_runner",
          "core/ai_artifact_contracts",
          "core/optimization_artifact_store",
          "examples/console_chat",
          "examples/direct_citadel_action"
        ]
      ],
      dependencies: dependencies(),
      artifacts: [
        outer_brain_contracts: artifact()
      ]
    ]
  end

  def artifact do
    [
      roots: ["core/outer_brain_contracts", "core/outer_brain_authority_evidence"],
      package: [
        name: "outer_brain_contracts",
        otp_app: :outer_brain_contracts,
        version: "0.1.0",
        description: "Projected semantic-runtime contract package from the OuterBrain workspace",
        docs_main: "readme-1"
      ],
      output: [
        docs: @artifact_docs,
        assets: ["CHANGELOG.md", "LICENSE"]
      ],
      verify: [
        artifact_tests: ["packaging/weld/outer_brain_contracts/test"],
        hex_build: false,
        hex_publish: false
      ]
    ]
  end

  defp dependencies do
    Enum.map(@manifest_dependencies, fn app ->
      {app, manifest_dependency(app)}
    end)
  end

  defp manifest_dependency(app) do
    config = Map.fetch!(dependency_configs(), app)
    github = Map.fetch!(config, :github)

    [opts: github_opts(github)]
  end

  defp dependency_configs do
    {config, _binding} =
      @repo_root
      |> Path.join("build_support/dependency_sources.config.exs")
      |> Code.eval_file()

    Map.new(config[:deps], fn {app, dep_config} -> {app, Map.new(dep_config)} end)
  end

  defp github_opts(github) do
    github = Map.new(github)
    repo = Map.fetch!(github, :repo)

    opts =
      github
      |> Map.take([:branch, :ref, :tag, :subdir])
      |> Enum.sort_by(fn {key, _value} -> key end)

    Keyword.merge([github: repo], opts)
  end
end

OuterBrain.Build.WeldContract.manifest()
