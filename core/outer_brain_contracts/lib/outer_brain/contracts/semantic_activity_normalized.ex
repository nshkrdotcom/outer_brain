defmodule OuterBrain.Contracts.SemanticActivityNormalized do
  @moduledoc """
  Workflow-safe normalized semantic activity result.

  Workflows receive compact refs, hashes, validation state, diagnostics refs,
  and bounded routing facts. Raw prompts, context packs, provider-native bodies,
  and large artifacts stay in Outer Brain or claim-check storage.
  """

  alias OuterBrain.Contracts.Phase4SemanticContract

  @contract_name "OuterBrain.SemanticActivityNormalized.v1"

  @validation_states [
    :valid,
    :coerced_valid,
    :degraded_valid,
    :needs_reask,
    :needs_human_review,
    :semantic_validation_failed_recoverable,
    :semantic_validation_failed_terminal,
    :semantic_security_quarantine,
    :semantic_integrity_quarantine
  ]

  @retry_classes [:none, :retryable, :repairable, :reask, :human_review, :terminal]
  @terminal_classes [:none, :semantic_terminal, :policy_terminal, :integrity_terminal]

  @required_routing_facts [
    :review_required,
    :semantic_score,
    :confidence_band,
    :risk_band,
    :schema_validation_state,
    :normalization_warning_count,
    :semantic_retry_class,
    :terminal_class,
    :review_reason_code
  ]

  @fields Phase4SemanticContract.scope_fields() ++
            [
              :principal_ref,
              :system_actor_ref,
              :semantic_ref,
              :provider_ref,
              :model_ref,
              :context_hash,
              :provenance_refs,
              :claim_check_refs,
              :normalized_summary,
              :routing_facts,
              :validation_state,
              :diagnostics_ref,
              :retry_class,
              :terminal_class,
              :normalizer_version,
              :workflow_history_payload
            ]

  @required_strings [
    :semantic_ref,
    :provider_ref,
    :model_ref,
    :context_hash,
    :diagnostics_ref,
    :normalizer_version
  ]

  defstruct [:contract_name | @fields]

  @type validation_state ::
          :valid
          | :coerced_valid
          | :degraded_valid
          | :needs_reask
          | :needs_human_review
          | :semantic_validation_failed_recoverable
          | :semantic_validation_failed_terminal
          | :semantic_security_quarantine
          | :semantic_integrity_quarantine

  @type t :: %__MODULE__{}

  @spec new(map() | t()) :: {:ok, t()} | {:error, term()}
  def new(%__MODULE__{} = contract), do: contract |> to_map() |> new()

  def new(attrs) when is_map(attrs) do
    with :ok <- reject_claim_check_only(attrs),
         :ok <- Phase4SemanticContract.reject_forbidden_attrs(attrs),
         :ok <- Phase4SemanticContract.required_scope(attrs),
         :ok <- Phase4SemanticContract.required_strings(attrs, @required_strings),
         {:ok, provenance_refs} <-
           Phase4SemanticContract.required_non_empty_list(attrs, :provenance_refs),
         {:ok, claim_check_refs} <-
           Phase4SemanticContract.required_non_empty_list(attrs, :claim_check_refs),
         {:ok, normalized_summary} <-
           Phase4SemanticContract.required_map(attrs, :normalized_summary),
         {:ok, routing_facts} <- routing_facts(attrs),
         {:ok, validation_state} <-
           Phase4SemanticContract.atom_value(attrs, :validation_state, @validation_states),
         {:ok, retry_class} <-
           Phase4SemanticContract.atom_value(attrs, :retry_class, @retry_classes),
         {:ok, terminal_class} <-
           Phase4SemanticContract.atom_value(attrs, :terminal_class, @terminal_classes) do
      {:ok,
       build(
         attrs,
         provenance_refs,
         claim_check_refs,
         normalized_summary,
         routing_facts,
         validation_state,
         retry_class,
         terminal_class
       )}
    end
  end

  def new(_attrs), do: {:error, :invalid_semantic_activity_normalized}

  @spec validation_states() :: [validation_state()]
  def validation_states, do: @validation_states

  @spec quarantine_state?(term()) :: boolean()
  def quarantine_state?(state),
    do: state in [:semantic_security_quarantine, :semantic_integrity_quarantine]

  @spec classify_normalization_condition(atom()) :: :diagnostic | :review_or_reask | :quarantine
  def classify_normalization_condition(condition)
      when condition in [:unknown_provider_keys, :safe_type_coercion, :low_confidence],
      do: :diagnostic

  def classify_normalization_condition(condition)
      when condition in [:missing_optional_field, :ambiguous_output],
      do: :review_or_reask

  def classify_normalization_condition(condition)
      when condition in [
             :tenant_mismatch,
             :missing_provenance,
             :hash_integrity_failure,
             :unsafe_content,
             :source_precedence_contradiction,
             :exhausted_recovery
           ],
      do: :quarantine

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = contract),
    do: Map.from_struct(contract) |> Map.delete(:contract_name)

  defp reject_claim_check_only(attrs) do
    claim_check_refs = Phase4SemanticContract.list_value(attrs, :claim_check_refs)
    routing_facts = Phase4SemanticContract.fetch_value(attrs, :routing_facts)

    if claim_check_refs != [] and routing_facts in [nil, %{}] and
         not Phase4SemanticContract.present?(attrs, :context_hash) do
      {:error, :claim_check_only_routing_result}
    else
      :ok
    end
  end

  defp routing_facts(attrs) do
    with {:ok, facts} <- Phase4SemanticContract.required_map(attrs, :routing_facts) do
      missing = Enum.reject(@required_routing_facts, &Map.has_key?(facts, &1))

      case missing do
        [] -> {:ok, facts}
        _missing -> {:error, {:missing_routing_facts, missing}}
      end
    end
  end

  defp build(
         attrs,
         provenance_refs,
         claim_check_refs,
         normalized_summary,
         routing_facts,
         validation_state,
         retry_class,
         terminal_class
       ) do
    workflow_history_payload = %{
      semantic_ref: Phase4SemanticContract.fetch_value(attrs, :semantic_ref),
      context_hash: Phase4SemanticContract.fetch_value(attrs, :context_hash),
      provenance_refs: provenance_refs,
      validation_state: validation_state,
      diagnostics_ref: Phase4SemanticContract.fetch_value(attrs, :diagnostics_ref),
      routing_facts: routing_facts,
      retry_class: retry_class,
      terminal_class: terminal_class
    }

    struct!(
      __MODULE__,
      Map.new(@fields, &{&1, Phase4SemanticContract.fetch_value(attrs, &1)})
      |> Map.put(:contract_name, @contract_name)
      |> Map.put(:provenance_refs, provenance_refs)
      |> Map.put(:claim_check_refs, claim_check_refs)
      |> Map.put(:normalized_summary, normalized_summary)
      |> Map.put(:routing_facts, routing_facts)
      |> Map.put(:validation_state, validation_state)
      |> Map.put(:retry_class, retry_class)
      |> Map.put(:terminal_class, terminal_class)
      |> Map.put(:workflow_history_payload, workflow_history_payload)
    )
  end
end
