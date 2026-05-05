Code.require_file("workspace_contract.exs", __DIR__)

defmodule OuterBrain.Build.WeldContract do
  @moduledoc false

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
        project_globs: OuterBrain.Build.WorkspaceContract.active_project_globs()
      ],
      classify: [
        tooling: ["."],
        proofs: ["examples/console_chat", "examples/direct_citadel_action"]
      ],
      publication: [
        internal_only: [".", "examples/console_chat", "examples/direct_citadel_action"]
      ],
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
end

OuterBrain.Build.WeldContract.manifest()
