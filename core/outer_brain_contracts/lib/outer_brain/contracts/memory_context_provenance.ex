defmodule OuterBrain.Contracts.MemoryContextProvenance do
  @moduledoc """
  Phase 7 memory context provenance contract.

  This extends the semantic context provenance surface with the recall proof,
  pinned snapshot epoch, source node, and commit-order evidence needed to replay
  why a fragment was admitted to a context pack.
  """

  alias OuterBrain.Contracts.Phase4SemanticContract

  @contract_name "OuterBrain.MemoryContextProvenance.v2"

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
              :redaction_policy_ref,
              :recall_proof_token_ref,
              :snapshot_epoch,
              :source_node_ref,
              :commit_lsn,
              :commit_hlc
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
    :redaction_policy_ref,
    :recall_proof_token_ref,
    :source_node_ref,
    :commit_lsn
  ]

  defstruct [:contract_name | @fields]

  @type t :: %__MODULE__{}

  @spec new(map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = contract), do: contract |> to_map() |> new()

  def new(attrs) when is_map(attrs) do
    with :ok <- Phase4SemanticContract.required_scope(attrs),
         :ok <- Phase4SemanticContract.required_strings(attrs, @required_strings),
         {:ok, provenance_refs} <-
           Phase4SemanticContract.required_non_empty_list(attrs, :provenance_refs),
         {:ok, snapshot_epoch} <- required_positive_integer(attrs, :snapshot_epoch),
         {:ok, commit_hlc} <- Phase4SemanticContract.required_map(attrs, :commit_hlc) do
      {:ok, build(attrs, provenance_refs, snapshot_epoch, commit_hlc)}
    end
  end

  def new(_attrs), do: {:error, :invalid_memory_context_provenance}

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = contract),
    do: Map.from_struct(contract) |> Map.delete(:contract_name)

  defp build(attrs, provenance_refs, snapshot_epoch, commit_hlc) do
    struct!(
      __MODULE__,
      Map.new(@fields, &{&1, Phase4SemanticContract.fetch_value(attrs, &1)})
      |> Map.put(:contract_name, @contract_name)
      |> Map.put(:provenance_refs, provenance_refs)
      |> Map.put(:snapshot_epoch, snapshot_epoch)
      |> Map.put(:commit_hlc, commit_hlc)
    )
  end

  defp required_positive_integer(attrs, field) do
    case Phase4SemanticContract.fetch_value(attrs, field) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _other -> {:error, {:invalid_field, field}}
    end
  end
end
