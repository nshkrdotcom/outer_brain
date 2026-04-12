defmodule OuterBrain.Bridges.ReviewBundle do
  @moduledoc """
  Projects a quality checkpoint into an operator-facing review bundle.
  """

  alias OuterBrain.Quality.Checkpoint

  @spec build(Checkpoint.t()) :: map()
  def build(%Checkpoint{} = checkpoint) do
    %{
      checkpoint_id: checkpoint.checkpoint_id,
      stage: checkpoint.stage,
      outcome: checkpoint.outcome,
      notes: checkpoint.notes,
      critical: checkpoint.critical
    }
  end
end
