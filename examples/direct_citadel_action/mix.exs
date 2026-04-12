defmodule OuterBrain.Examples.DirectCitadelAction.MixProject do
  use Mix.Project

  def project do
    [
      app: :outer_brain_direct_citadel_action,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      dialyzer: dialyzer(),
      name: "OuterBrain Direct Citadel Action",
      description: "Direct action-compilation smoke example for the OuterBrain workspace"
    ]
  end

  def application do
    [extra_applications: [:logger]]
  end

  def cli do
    [preferred_envs: [dialyzer: :test]]
  end

  defp deps do
    [
      {:outer_brain_core, path: "../../core/outer_brain_core"},
      {:outer_brain_citadel_bridge, path: "../../bridges/citadel_bridge"},
      {:outer_brain_domain_bridge, path: "../../bridges/domain_bridge"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [main: "readme", extras: ["README.md"]]
  end

  defp dialyzer do
    [plt_add_deps: :apps_direct]
  end
end
