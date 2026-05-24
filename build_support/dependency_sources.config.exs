repo_root = Path.expand("..", __DIR__)
siblings_root = Path.expand("..", repo_root)

%{
  deps: %{
    ground_plane_contracts: %{
      path: Path.join(siblings_root, "ground_plane/core/ground_plane_contracts"),
      github: %{
        repo: "nshkrdotcom/ground_plane",
        branch: "main",
        subdir: "core/ground_plane_contracts"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    jido_integration_provider_classification: %{
      path: Path.join(siblings_root, "jido_integration/core/provider_classification"),
      github: %{
        repo: "agentjido/jido_integration",
        branch: "main",
        subdir: "core/provider_classification"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    citadel_domain_surface: %{
      path: Path.join(siblings_root, "citadel/surfaces/citadel_domain_surface"),
      github: %{
        repo: "nshkrdotcom/citadel",
        branch: "main",
        subdir: "surfaces/citadel_domain_surface"
      },
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    },
    mezzanine_eval_engine: %{
      path: Path.join(siblings_root, "mezzanine/core/eval_engine"),
      github: %{repo: "nshkrdotcom/mezzanine", branch: "main", subdir: "core/eval_engine"},
      hex: "~> 0.1.0",
      default_order: [:path, :github, :hex],
      publish_order: [:hex]
    }
  }
}
