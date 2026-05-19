defmodule OuterBrain.MemoryContracts.ContextBudgetRef do
  @moduledoc "Opaque context budget ref."

  alias OuterBrain.MemoryContracts.Validator

  @enforce_keys [
    :budget_ref,
    :tenant_ref,
    :authority_ref,
    :installation_ref,
    :trace_ref
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          budget_ref: String.t(),
          tenant_ref: String.t(),
          authority_ref: String.t(),
          installation_ref: String.t(),
          trace_ref: String.t()
        }

  @spec new(map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = ref), do: {:ok, ref}

  def new(attrs) when is_map(attrs) do
    with {:ok, budget_ref} <- Validator.required_string(attrs, :budget_ref),
         {:ok, tenant_ref} <- Validator.required_string(attrs, :tenant_ref),
         {:ok, authority_ref} <- Validator.required_string(attrs, :authority_ref),
         {:ok, installation_ref} <- Validator.required_string(attrs, :installation_ref),
         {:ok, trace_ref} <- Validator.required_string(attrs, :trace_ref) do
      {:ok,
       %__MODULE__{
         budget_ref: budget_ref,
         tenant_ref: tenant_ref,
         authority_ref: authority_ref,
         installation_ref: installation_ref,
         trace_ref: trace_ref
       }}
    end
  end

  def new(_attrs), do: {:error, :invalid_context_budget_ref}
end
