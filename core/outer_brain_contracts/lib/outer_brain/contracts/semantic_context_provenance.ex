defmodule OuterBrain.Contracts.SemanticContextProvenance do
  @moduledoc """
  Phase 4 semantic context provenance contract.

  The contract keeps provider, model, prompt, claim-check, normalizer, and
  redaction provenance explicit without allowing raw semantic payloads to become
  workflow or AppKit DTO state.
  """

  alias OuterBrain.Contracts.Phase4SemanticContract

  @contract_name "OuterBrain.SemanticContextProvenance.v1"
  @fields Phase4SemanticContract.scope_fields() ++
            [
              :principal_ref,
              :system_actor_ref,
              :semantic_ref,
              :provider_ref,
              :model_ref,
              :prompt_hash,
              :context_hash,
              :input_claim_check_ref,
              :output_claim_check_ref,
              :provenance_refs,
              :normalizer_version,
              :redaction_policy_ref
            ]

  @required_strings [
    :semantic_ref,
    :provider_ref,
    :model_ref,
    :prompt_hash,
    :context_hash,
    :input_claim_check_ref,
    :output_claim_check_ref,
    :normalizer_version,
    :redaction_policy_ref
  ]

  defstruct [:contract_name | @fields]

  @type t :: %__MODULE__{}

  @spec new(map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = contract), do: contract |> to_map() |> new()

  def new(attrs) when is_map(attrs) do
    with :ok <- Phase4SemanticContract.required_scope(attrs),
         :ok <- Phase4SemanticContract.required_strings(attrs, @required_strings),
         {:ok, provenance_refs} <-
           Phase4SemanticContract.required_non_empty_list(attrs, :provenance_refs) do
      {:ok, build(attrs, provenance_refs)}
    end
  end

  def new(_attrs), do: {:error, :invalid_semantic_context_provenance}

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = contract),
    do: Map.from_struct(contract) |> Map.delete(:contract_name)

  defp build(attrs, provenance_refs) do
    struct!(
      __MODULE__,
      Map.new(@fields, &{&1, Phase4SemanticContract.fetch_value(attrs, &1)})
      |> Map.put(:contract_name, @contract_name)
      |> Map.put(:provenance_refs, provenance_refs)
    )
  end
end
