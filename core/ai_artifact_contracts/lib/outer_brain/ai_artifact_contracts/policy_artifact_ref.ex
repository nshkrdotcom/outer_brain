defmodule OuterBrain.AIArtifactContracts.PolicyArtifactRef do
  @moduledoc "Lineage and rollback-bearing policy artifact ref."

  alias OuterBrain.AIArtifactContracts.{Validator, Vocabulary}

  @enforce_keys [
    :artifact_ref,
    :artifact_kind,
    :tenant_ref,
    :source_ref,
    :lineage_ref,
    :rollback_ref,
    :trace_ref,
    :redaction_policy_ref
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    with :ok <- Validator.reject_raw_payload(attrs),
         :ok <- Validator.reject_out_of_scope_owner(attrs),
         :ok <- Validator.required(attrs, Vocabulary.policy_artifact_fields()),
         {:ok, artifact_kind} <-
           Validator.member(attrs, :artifact_kind, Vocabulary.policy_artifact_kinds()) do
      {:ok,
       %__MODULE__{
         artifact_ref: Validator.value!(attrs, :artifact_ref),
         artifact_kind: artifact_kind,
         tenant_ref: Validator.value!(attrs, :tenant_ref),
         source_ref: Validator.value!(attrs, :source_ref),
         lineage_ref: Validator.value!(attrs, :lineage_ref),
         rollback_ref: Validator.value!(attrs, :rollback_ref),
         trace_ref: Validator.value!(attrs, :trace_ref),
         redaction_policy_ref: Validator.value!(attrs, :redaction_policy_ref)
       }}
    end
  end
end
