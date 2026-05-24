unless Code.ensure_loaded?(DependencySources) do
  Code.require_file("../../build_support/dependency_sources.exs", __DIR__)
end

defmodule OuterBrain.ContextABI.MixProject do
  use Mix.Project

  @repo_root Path.expand("../..", __DIR__)

  def project do
    [
      app: :outer_brain_context_abi,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [main: "readme", extras: ["README.md"]],
      dialyzer: [plt_add_deps: :apps_direct],
      name: "OuterBrain Context ABI",
      description: "Ref-only context packet contracts and deterministic Context ABI compiler"
    ]
  end

  def application do
    [extra_applications: [:crypto, :logger]]
  end

  def cli do
    [preferred_envs: [ci: :test]]
  end

  defp deps do
    [
      DependencySources.dep(:ground_plane_contracts, @repo_root),
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
