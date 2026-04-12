defmodule OuterBrain.HostSurface.MixProject do
  use Mix.Project

  def project do
    [
      app: :outer_brain_host_surface,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      dialyzer: dialyzer(),
      name: "OuterBrain Host Surface",
      description: "Minimal host-facing semantic runtime entrypoint for the OuterBrain workspace"
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {OuterBrain.HostSurface.Application, []}
    ]
  end

  def cli do
    [preferred_envs: [dialyzer: :test]]
  end

  defp deps do
    [
      {:outer_brain_runtime, path: "../../core/outer_brain_runtime"},
      {:outer_brain_domain_bridge, path: "../../bridges/domain_bridge"},
      {:outer_brain_publication_bridge, path: "../../bridges/publication_bridge"},
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
