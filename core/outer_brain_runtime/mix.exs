defmodule OuterBrain.Runtime.MixProject do
  use Mix.Project

  def project do
    [
      app: :outer_brain_runtime,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      dialyzer: dialyzer(),
      name: "OuterBrain Runtime",
      description:
        "Live session ownership, wake coordination, and streaming control for OuterBrain"
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
      {:outer_brain_contracts, path: "../outer_brain_contracts"},
      {:outer_brain_journal, path: "../outer_brain_journal"},
      {:outer_brain_core, path: "../outer_brain_core"},
      {:outer_brain_prompting, path: "../outer_brain_prompting"},
      {:outer_brain_quality, path: "../outer_brain_quality"},
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
