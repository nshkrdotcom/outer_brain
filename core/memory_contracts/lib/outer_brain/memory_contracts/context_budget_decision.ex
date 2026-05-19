defmodule OuterBrain.MemoryContracts.ContextBudgetDecision do
  @moduledoc "Budget admission decision with bounded result and reason vocabularies."

  alias OuterBrain.MemoryContracts.{Validator, Vocabulary}

  @enforce_keys [
    :budget_ref,
    :decision,
    :requested_units,
    :granted_units,
    :residual_units
  ]
  defstruct [:reason | @enforce_keys]

  @type t :: %__MODULE__{
          budget_ref: String.t(),
          decision: atom(),
          reason: atom() | nil,
          requested_units: non_neg_integer(),
          granted_units: non_neg_integer(),
          residual_units: non_neg_integer()
        }

  @spec new(map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = decision), do: {:ok, decision}

  def new(attrs) when is_map(attrs) do
    with {:ok, budget_ref} <- Validator.required_string(attrs, :budget_ref),
         {:ok, decision} <-
           Validator.required_member(attrs, :decision, Vocabulary.budget_decisions()),
         {:ok, requested_units} <-
           Validator.required_non_negative_integer(attrs, :requested_units),
         {:ok, granted_units} <- Validator.required_non_negative_integer(attrs, :granted_units),
         {:ok, residual_units} <- Validator.required_non_negative_integer(attrs, :residual_units),
         :ok <- Validator.allowed_decision_reason(attrs, decision) do
      {:ok,
       %__MODULE__{
         budget_ref: budget_ref,
         decision: decision,
         reason:
           Validator.optional_member(attrs, :reason, Vocabulary.budget_exhaustion_reasons()),
         requested_units: requested_units,
         granted_units: granted_units,
         residual_units: residual_units
       }}
    end
  end

  def new(_attrs), do: {:error, :invalid_context_budget_decision}
end
