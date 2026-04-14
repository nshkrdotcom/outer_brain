defmodule OuterBrainContracts.MixProject do
  use Mix.Project

  def project do
    [
      app: :outer_brain_contracts,
      version: "0.1.0",
      build_path: "_build",
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      erlc_paths: ["components/core/outer_brain_contracts/src"],
      deps: deps(),
      description: "Projected semantic-runtime contract package from the OuterBrain workspace",
      package: package(),
      docs: docs()
    ]
  end

  def application do
    [extra_applications: [:crypto, :logger]]
  end

  def elixirc_paths(:test) do
    base = ["config", "components/core/outer_brain_contracts/lib"]

    if File.dir?("test/support") do
      base ++ ["test/support"]
    else
      base
    end
  end

  def elixirc_paths(_env), do: ["config", "components/core/outer_brain_contracts/lib"]

  defp deps do
    [
      {:ex_doc, "~> 0.40", [only: :dev, runtime: false]}
    ]
  end

  defp package do
    [
      licenses: ["MIT"],
      maintainers: [],
      links: %{"Source" => "https://github.com/nshkrdotcom/outer_brain"},
      files: [
        ".formatter.exs",
        "CHANGELOG.md",
        "LICENSE",
        "README.md",
        "components/core/outer_brain_contracts",
        "config",
        "docs/integration_surface.md",
        "docs/layout.md",
        "docs/overview.md",
        "docs/runtime_model.md",
        "mix.exs",
        "projection.lock.json"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: [
        "README.md",
        "docs/integration_surface.md",
        "docs/layout.md",
        "docs/overview.md",
        "docs/runtime_model.md"
      ]
    ]
  end
end
