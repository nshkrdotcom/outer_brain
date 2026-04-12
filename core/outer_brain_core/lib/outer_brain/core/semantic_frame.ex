defmodule OuterBrain.Core.SemanticFrame do
  @moduledoc """
  Reducer for the durable semantic frame.
  """

  defstruct [
    :session_id,
    :objective,
    unresolved_questions: [],
    commitments: [],
    last_fact_id: nil
  ]

  @type t :: %__MODULE__{
          session_id: String.t(),
          objective: String.t(),
          unresolved_questions: [String.t()],
          commitments: [String.t()],
          last_fact_id: String.t() | nil
        }

  @spec seed(String.t(), String.t()) :: t()
  def seed(session_id, objective) when is_binary(session_id) and is_binary(objective) do
    %__MODULE__{session_id: session_id, objective: objective}
  end

  @spec apply_turn(t(), map()) :: t()
  def apply_turn(%__MODULE__{} = frame, %{objective: objective}) when is_binary(objective) do
    %__MODULE__{frame | objective: objective}
  end

  def apply_turn(%__MODULE__{} = frame, %{question: question}) when is_binary(question) do
    %__MODULE__{frame | unresolved_questions: Enum.uniq(frame.unresolved_questions ++ [question])}
  end

  def apply_turn(%__MODULE__{} = frame, _turn), do: frame

  @spec record_commitment(t(), String.t()) :: t()
  def record_commitment(%__MODULE__{} = frame, commitment) when is_binary(commitment) do
    %__MODULE__{frame | commitments: Enum.uniq(frame.commitments ++ [commitment])}
  end

  @spec wake(t(), String.t()) :: t()
  def wake(%__MODULE__{} = frame, fact_id) when is_binary(fact_id) do
    %__MODULE__{frame | last_fact_id: fact_id}
  end
end
