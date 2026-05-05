defmodule OuterBrainAuthorityEvidence.MixProject do
  use Mix.Project

  def project do
    [
      app: :outer_brain_authority_evidence,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [main: "readme", extras: ["README.md"]],
      dialyzer: [plt_add_deps: :apps_direct],
      name: "OuterBrain Authority Evidence",
      description: "Tenant-scoped ref-only prompt and memory authority evidence"
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  def cli do
    [preferred_envs: [ci: :test, dialyzer: :test]]
  end

  defp deps do
    [
      {:outer_brain_contracts, path: "../outer_brain_contracts", runtime: false},
      {:outer_brain_core, path: "../outer_brain_core", runtime: false},
      {:outer_brain_prompting, path: "../outer_brain_prompting", runtime: false},
      {:outer_brain_quality, path: "../outer_brain_quality", runtime: false},
      {:outer_brain_runtime, path: "../outer_brain_runtime", runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
