repo_root = Path.expand("..", __DIR__)
siblings_root = Path.expand("..", repo_root)

%{
  deps: %{
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
