defmodule OuterBrain.MemoryContracts.MemoryRef do
  @moduledoc "Opaque memory reference. It never carries raw bodies."

  alias OuterBrain.MemoryContracts.{MemoryScopeKey, Validator, Vocabulary}

  @enforce_keys [:memory_id, :scope_key, :tier, :revision, :tenant_ref]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          memory_id: String.t(),
          scope_key: MemoryScopeKey.t(),
          tier: atom(),
          revision: pos_integer(),
          tenant_ref: String.t()
        }

  @spec new(map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = ref), do: {:ok, ref}

  def new(attrs) when is_map(attrs) do
    with :ok <- Validator.reject_raw_payload(attrs),
         {:ok, memory_id} <- Validator.required_string(attrs, :memory_id),
         {:ok, scope_key} <- attrs |> Validator.fetch_value(:scope_key) |> MemoryScopeKey.new(),
         {:ok, tier} <- Validator.required_member(attrs, :tier, Vocabulary.memory_tiers()),
         {:ok, revision} <- Validator.required_positive_integer(attrs, :revision),
         {:ok, tenant_ref} <- Validator.required_string(attrs, :tenant_ref) do
      {:ok,
       %__MODULE__{
         memory_id: memory_id,
         scope_key: scope_key,
         tier: tier,
         revision: revision,
         tenant_ref: tenant_ref
       }}
    end
  end

  def new(_attrs), do: {:error, :invalid_memory_ref}
end
