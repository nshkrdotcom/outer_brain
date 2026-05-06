defmodule OuterBrain.EvalRunner.MixProject do
  use Mix.Project

  def project do
    [
      app: :outer_brain_eval_runner,
      version: "0.1.0",
      elixir: "~> 1.19",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: [main: "readme", extras: ["README.md"]],
      dialyzer: [plt_add_deps: :apps_tree],
      name: "OuterBrain Eval Runner",
      description: "Prompt, model, policy, guard, and memory variant eval runner"
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
      {:mezzanine_eval_engine, path: "../../../mezzanine/core/eval_engine"},
      {:outer_brain_prompt_fabric, path: "../prompt_fabric"},
      {:outer_brain_guardrail_contracts, path: "../guardrail_contracts"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.40.1", only: :dev, runtime: false}
    ]
  end
end
