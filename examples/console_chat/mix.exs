defmodule OuterBrain.Examples.ConsoleChat.MixProject do
  use Mix.Project

  def project do
    [
      app: :outer_brain_console_chat,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      dialyzer: dialyzer(),
      name: "OuterBrain Console Chat",
      description: "Console-chat smoke example for the OuterBrain workspace"
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
      {:outer_brain_host_surface, path: "../../apps/host_surface"},
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
