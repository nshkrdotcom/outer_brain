defmodule OuterBrain.Quality.Checkpoint do
  @moduledoc """
  Durable quality-checkpoint contract.
  """

  defstruct [:checkpoint_id, :stage, :outcome, notes: [], critical: false]

  @type outcome :: :pass | :clarify | :reject

  @type t :: %__MODULE__{
          checkpoint_id: String.t(),
          stage: atom(),
          outcome: outcome(),
          notes: [String.t()],
          critical: boolean()
        }

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(%{checkpoint_id: checkpoint_id, stage: stage, outcome: outcome} = attrs)
      when is_binary(checkpoint_id) and is_atom(stage) and outcome in [:pass, :clarify, :reject] do
    {:ok,
     %__MODULE__{
       checkpoint_id: checkpoint_id,
       stage: stage,
       outcome: outcome,
       notes: Map.get(attrs, :notes, []),
       critical: Map.get(attrs, :critical, false)
     }}
  end

  def new(_attrs), do: {:error, :invalid_checkpoint}
end
