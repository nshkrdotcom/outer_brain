defmodule OuterBrain.Persistence.MixProject do
  use Mix.Project

  def project do
    [
      app: :outer_brain_persistence,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      dialyzer: dialyzer(),
      name: "OuterBrain Persistence",
      description: "Raw Ecto/Postgres durability layer for OuterBrain restart-critical state"
    ]
  end

  def application do
    [
      mod: {OuterBrain.Persistence.Application, []},
      extra_applications: [:logger, :ecto_sql]
    ]
  end

  def cli do
    [preferred_envs: [dialyzer: :test]]
  end

  defp deps do
    [
      {:ecto_sql, "~> 3.13"},
      {:postgrex, "~> 0.22"},
      {:jason, "~> 1.4"},
      {:outer_brain_contracts, path: "../outer_brain_contracts"},
      {:outer_brain_journal, path: "../outer_brain_journal"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [main: "readme", extras: ["README.md"]]
  end

  defp dialyzer do
    [plt_add_deps: :apps_direct, plt_add_apps: [:ecto]]
  end
end
