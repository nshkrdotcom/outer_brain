defmodule OuterBrain.MemoryContracts.MemoryEvidenceRef do
  @moduledoc "Bounded memory evidence reference."

  alias OuterBrain.MemoryContracts.Validator

  @enforce_keys [
    :memory_id,
    :evidence_hash,
    :evidence_owner_ref,
    :release_manifest_ref,
    :redaction_policy_ref
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          memory_id: String.t(),
          evidence_hash: String.t(),
          evidence_owner_ref: String.t(),
          release_manifest_ref: String.t(),
          redaction_policy_ref: String.t()
        }

  @spec new(map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = ref), do: {:ok, ref}

  def new(attrs) when is_map(attrs) do
    with :ok <- Validator.reject_raw_payload(attrs),
         {:ok, memory_id} <- Validator.required_string(attrs, :memory_id),
         {:ok, evidence_hash} <- Validator.required_string(attrs, :evidence_hash),
         {:ok, evidence_owner_ref} <- Validator.required_string(attrs, :evidence_owner_ref),
         {:ok, release_manifest_ref} <- Validator.required_string(attrs, :release_manifest_ref),
         {:ok, redaction_policy_ref} <- Validator.required_string(attrs, :redaction_policy_ref) do
      {:ok,
       %__MODULE__{
         memory_id: memory_id,
         evidence_hash: evidence_hash,
         evidence_owner_ref: evidence_owner_ref,
         release_manifest_ref: release_manifest_ref,
         redaction_policy_ref: redaction_policy_ref
       }}
    end
  end

  def new(_attrs), do: {:error, :invalid_memory_evidence_ref}
end
