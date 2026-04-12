defmodule OuterBrain.Prompting.StrategyProfile do
  @moduledoc """
  Stable strategy profiles for context assembly and response posture.
  """

  @profiles %{
    conservative: %{temperature: 0.1, clarification_threshold: 0.75, max_refs: 6},
    balanced: %{temperature: 0.3, clarification_threshold: 0.6, max_refs: 10}
  }

  @spec fetch(atom()) :: {:ok, map()} | {:error, :unknown_profile}
  def fetch(name) when is_atom(name) do
    case Map.fetch(@profiles, name) do
      {:ok, profile} -> {:ok, Map.put(profile, :name, name)}
      :error -> {:error, :unknown_profile}
    end
  end
end
