defmodule OuterBrain.MixProject do
  use Mix.Project

  @version "0.1.0"
  @source_url "https://github.com/nshkrdotcom/outer_brain"
  @description "Starter semantic-runtime repository for context assembly, semantic state, intent synthesis, and restart-safe reply publication above Citadel."

  def project do
    [
      app: :outer_brain,
      version: @version,
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      aliases: aliases(),
      description: @description,
      package: package(),
      docs: docs(),
      source_url: @source_url,
      homepage_url: @source_url,
      name: "OuterBrain"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {OuterBrain.Application, []}
    ]
  end

  def cli do
    [
      preferred_envs: [
        ci: :test
      ]
    ]
  end

  defp deps do
    [
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.38", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      ci: [
        "format --check-formatted",
        "compile --warnings-as-errors",
        "test"
      ]
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: ["nshkrdotcom"],
      links: %{
        "GitHub" => @source_url
      },
      files: ~w(.formatter.exs CHANGELOG.md LICENSE README.md assets docs lib mix.exs test)
    ]
  end

  defp docs do
    [
      main: "readme",
      name: "OuterBrain",
      logo: "assets/outer_brain.svg",
      assets: %{"assets" => "assets"},
      source_ref: "main",
      source_url: @source_url,
      homepage_url: @source_url,
      extras: [
        "README.md",
        "docs/overview.md",
        "docs/runtime_model.md",
        "docs/integration_surface.md",
        "CHANGELOG.md",
        "LICENSE"
      ],
      groups_for_extras: [
        Overview: ["README.md", "docs/overview.md"],
        Runtime: ["docs/runtime_model.md", "docs/integration_surface.md"],
        Project: ["CHANGELOG.md", "LICENSE"]
      ]
    ]
  end
end
