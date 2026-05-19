defmodule OuterBrain.MemoryContracts.MemoryScopeKey do
  @moduledoc "Bounded memory scope key."

  alias OuterBrain.MemoryContracts.Validator

  @enforce_keys [:tenant_ref, :installation_ref, :subject_ref]
  defstruct [:tenant_ref, :installation_ref, :subject_ref, :run_ref, :agent_ref, :skill_ref]

  @type t :: %__MODULE__{
          tenant_ref: String.t(),
          installation_ref: String.t(),
          subject_ref: String.t(),
          run_ref: String.t() | nil,
          agent_ref: String.t() | nil,
          skill_ref: String.t() | nil
        }

  @spec new(map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = scope), do: {:ok, scope}

  def new(attrs) when is_map(attrs) do
    with :ok <- Validator.reject_raw_payload(attrs),
         {:ok, tenant_ref} <- Validator.required_string(attrs, :tenant_ref),
         {:ok, installation_ref} <- Validator.required_string(attrs, :installation_ref),
         {:ok, subject_ref} <- Validator.required_string(attrs, :subject_ref),
         :ok <- Validator.bounded_optional_refs(attrs, [:run_ref, :agent_ref, :skill_ref]) do
      {:ok,
       %__MODULE__{
         tenant_ref: tenant_ref,
         installation_ref: installation_ref,
         subject_ref: subject_ref,
         run_ref: Validator.optional_string(attrs, :run_ref),
         agent_ref: Validator.optional_string(attrs, :agent_ref),
         skill_ref: Validator.optional_string(attrs, :skill_ref)
       }}
    end
  end

  def new(_attrs), do: {:error, :invalid_memory_scope_key}
end
