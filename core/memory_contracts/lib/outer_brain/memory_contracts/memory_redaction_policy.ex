defmodule OuterBrain.MemoryContracts.MemoryRedactionPolicy do
  @moduledoc "Bounded redaction policy."

  alias OuterBrain.MemoryContracts.{Validator, Vocabulary}

  @enforce_keys [:level, :redaction_policy_ref]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          level: atom(),
          redaction_policy_ref: String.t()
        }

  @spec new(map() | atom() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = policy), do: {:ok, policy}

  def new(attrs) when is_map(attrs) do
    with {:ok, level} <- Validator.required_member(attrs, :level, Vocabulary.redaction_levels()),
         {:ok, redaction_policy_ref} <- Validator.required_string(attrs, :redaction_policy_ref) do
      {:ok, %__MODULE__{level: level, redaction_policy_ref: redaction_policy_ref}}
    end
  end

  def new(level) when is_atom(level) do
    if level in Vocabulary.redaction_levels() do
      {:ok,
       %__MODULE__{
         level: level,
         redaction_policy_ref: "memory-redaction-policy://#{level}"
       }}
    else
      {:error, :invalid_memory_redaction_policy}
    end
  end

  def new(_attrs), do: {:error, :invalid_memory_redaction_policy}
end
