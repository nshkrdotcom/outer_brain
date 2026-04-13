defmodule OuterBrain.DomainBridge.MixProject do
  use Mix.Project

  @default_jido_domain_path "/home/home/p/g/n/jido_domain"
  @jido_domain_path_env "OUTER_BRAIN_JIDO_DOMAIN_PATH"

  def project do
    [
      app: :outer_brain_domain_bridge,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      dialyzer: dialyzer(),
      name: "OuterBrain Domain Bridge",
      description: "Manifest compilation bridge from typed routes into OuterBrain"
    ]
  end

  def application do
    [extra_applications: [:crypto, :logger]]
  end

  def cli do
    [preferred_envs: [dialyzer: :test]]
  end

  defp deps do
    [
      {:outer_brain_contracts, path: "../../core/outer_brain_contracts"},
      {:outer_brain_core, path: "../../core/outer_brain_core"},
      {:jido_domain, path: jido_domain_path()},
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

  defp jido_domain_path do
    System.get_env(@jido_domain_path_env, @default_jido_domain_path)
  end
end
