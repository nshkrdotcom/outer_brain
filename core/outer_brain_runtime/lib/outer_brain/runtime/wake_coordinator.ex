defmodule OuterBrain.Runtime.WakeCoordinator do
  @moduledoc """
  Chooses exactly one semantic follow-up path for a normalized fact.
  """

  @spec next_follow_up(map()) :: atom()
  def next_follow_up(%{wake_path: wake_path}) when is_atom(wake_path), do: wake_path
end
