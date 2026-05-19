defmodule OuterBrain.MemoryContracts.MemoryAccessReason do
  @moduledoc "Bounded access reason."

  alias OuterBrain.MemoryContracts.{Validator, Vocabulary}

  @enforce_keys [:reason]
  defstruct @enforce_keys

  @type t :: %__MODULE__{reason: atom()}

  @spec new(map() | atom() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = reason), do: {:ok, reason}

  def new(reason) when is_atom(reason) do
    if reason in Vocabulary.access_reasons() do
      {:ok, %__MODULE__{reason: reason}}
    else
      {:error, :unknown_memory_access_reason}
    end
  end

  def new(attrs) when is_map(attrs) do
    with {:ok, reason} <- Validator.required_member(attrs, :reason, Vocabulary.access_reasons()) do
      {:ok, %__MODULE__{reason: reason}}
    end
  end

  def new(_reason), do: {:error, :unknown_memory_access_reason}
end
