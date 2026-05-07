defmodule OuterBrain.OptimizationArtifactStore do
  @moduledoc """
  Ref-only adaptive artifact graph history.
  """

  alias OuterBrain.AIArtifactContracts

  @promotion_fields [
    :promotion_ref,
    :tenant_ref,
    :source_artifact_refs,
    :target_artifact_refs,
    :eval_evidence_refs,
    :replay_bundle_ref,
    :rollback_ref,
    :trace_ref,
    :redaction_policy_ref
  ]
  @rollback_fields [
    :rollback_ref,
    :tenant_ref,
    :restored_artifact_refs,
    :invalidated_artifact_refs,
    :trace_ref,
    :redaction_policy_ref
  ]
  @raw_keys [
    :body,
    :raw_body,
    :prompt_body,
    :raw_prompt,
    :provider_payload,
    :raw_provider_payload,
    :payload,
    :raw_payload,
    :memory_body,
    :model_output,
    :tool_input,
    :tool_output,
    :credential_body,
    :api_key,
    :authorization_header,
    "body",
    "raw_body",
    "prompt_body",
    "raw_prompt",
    "provider_payload",
    "raw_provider_payload",
    "payload",
    "raw_payload",
    "memory_body",
    "model_output",
    "tool_input",
    "tool_output",
    "credential_body",
    "api_key",
    "authorization_header"
  ]

  defmodule Store do
    @moduledoc "In-memory ref graph state."
    defstruct artifacts: %{}, promotions: %{}, rollbacks: %{}
    @type t :: %__MODULE__{}
  end

  defmodule PromotionDecision do
    @moduledoc "Promotion decision refs and evidence refs."
    @enforce_keys [
      :promotion_ref,
      :tenant_ref,
      :source_artifact_refs,
      :target_artifact_refs,
      :eval_evidence_refs,
      :replay_bundle_ref,
      :rollback_ref,
      :trace_ref,
      :redaction_policy_ref
    ]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule RollbackDecision do
    @moduledoc "Rollback decision refs."
    @enforce_keys [
      :rollback_ref,
      :tenant_ref,
      :restored_artifact_refs,
      :invalidated_artifact_refs,
      :trace_ref,
      :redaction_policy_ref
    ]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  @spec new() :: Store.t()
  def new, do: %Store{}

  @spec record_artifact(Store.t(), map()) ::
          {:ok, Store.t(), struct()} | {:error, term()}
  def record_artifact(%Store{} = store, attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         :ok <- reject_out_of_scope_owner(attrs),
         {:ok, artifact} <- AIArtifactContracts.policy_artifact_ref(attrs) do
      {:ok, put_in(store.artifacts[artifact.artifact_ref], artifact), artifact}
    end
  end

  @spec record_promotion(Store.t(), map()) ::
          {:ok, Store.t(), PromotionDecision.t()} | {:error, term()}
  def record_promotion(%Store{} = store, attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         :ok <- reject_out_of_scope_owner(attrs),
         :ok <- required(attrs, @promotion_fields),
         source_refs when is_list(source_refs) <- value(attrs, :source_artifact_refs),
         target_refs when is_list(target_refs) <- value(attrs, :target_artifact_refs),
         eval_refs when is_list(eval_refs) <- value(attrs, :eval_evidence_refs) do
      promotion = %PromotionDecision{
        promotion_ref: value!(attrs, :promotion_ref),
        tenant_ref: value!(attrs, :tenant_ref),
        source_artifact_refs: source_refs,
        target_artifact_refs: target_refs,
        eval_evidence_refs: eval_refs,
        replay_bundle_ref: value!(attrs, :replay_bundle_ref),
        rollback_ref: value!(attrs, :rollback_ref),
        trace_ref: value!(attrs, :trace_ref),
        redaction_policy_ref: value!(attrs, :redaction_policy_ref)
      }

      {:ok, put_in(store.promotions[promotion.promotion_ref], promotion), promotion}
    else
      _other -> {:error, :invalid_promotion_decision}
    end
  end

  @spec record_rollback(Store.t(), map()) ::
          {:ok, Store.t(), RollbackDecision.t()} | {:error, term()}
  def record_rollback(%Store{} = store, attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         :ok <- reject_out_of_scope_owner(attrs),
         :ok <- required(attrs, @rollback_fields),
         restored_refs when is_list(restored_refs) <- value(attrs, :restored_artifact_refs),
         invalidated_refs when is_list(invalidated_refs) <-
           value(attrs, :invalidated_artifact_refs) do
      rollback = %RollbackDecision{
        rollback_ref: value!(attrs, :rollback_ref),
        tenant_ref: value!(attrs, :tenant_ref),
        restored_artifact_refs: restored_refs,
        invalidated_artifact_refs: invalidated_refs,
        trace_ref: value!(attrs, :trace_ref),
        redaction_policy_ref: value!(attrs, :redaction_policy_ref)
      }

      {:ok, put_in(store.rollbacks[rollback.rollback_ref], rollback), rollback}
    else
      _other -> {:error, :invalid_rollback_decision}
    end
  end

  @spec project(Store.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def project(%Store{} = store, ref) when is_binary(ref) do
    cond do
      Map.has_key?(store.promotions, ref) ->
        promotion = Map.fetch!(store.promotions, ref)

        {:ok,
         %{
           redacted: true,
           kind: :promotion_decision,
           promotion_ref: promotion.promotion_ref,
           tenant_ref: promotion.tenant_ref,
           source_artifact_refs: promotion.source_artifact_refs,
           target_artifact_refs: promotion.target_artifact_refs,
           eval_evidence_refs: promotion.eval_evidence_refs,
           replay_bundle_ref: promotion.replay_bundle_ref,
           rollback_ref: promotion.rollback_ref,
           trace_ref: promotion.trace_ref,
           redaction_policy_ref: promotion.redaction_policy_ref
         }}

      Map.has_key?(store.artifacts, ref) ->
        artifact = Map.fetch!(store.artifacts, ref)

        {:ok,
         %{
           redacted: true,
           kind: artifact.artifact_kind,
           artifact_ref: artifact.artifact_ref,
           tenant_ref: artifact.tenant_ref,
           source_ref: artifact.source_ref,
           lineage_ref: artifact.lineage_ref,
           rollback_ref: artifact.rollback_ref,
           trace_ref: artifact.trace_ref,
           redaction_policy_ref: artifact.redaction_policy_ref
         }}

      Map.has_key?(store.rollbacks, ref) ->
        rollback = Map.fetch!(store.rollbacks, ref)

        {:ok,
         %{
           redacted: true,
           kind: :rollback_decision,
           rollback_ref: rollback.rollback_ref,
           tenant_ref: rollback.tenant_ref,
           restored_artifact_refs: rollback.restored_artifact_refs,
           invalidated_artifact_refs: rollback.invalidated_artifact_refs,
           trace_ref: rollback.trace_ref,
           redaction_policy_ref: rollback.redaction_policy_ref
         }}

      true ->
        {:error, {:unknown_artifact_ref, ref}}
    end
  end

  defp reject_raw_payload(attrs) do
    case Enum.find(@raw_keys, &has_key_deep?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_ai_artifact_payload_forbidden, key}}
    end
  end

  defp reject_out_of_scope_owner(attrs) do
    owner_scope = value(attrs, :owner_scope)

    if not is_nil(owner_scope) and owner_scope not in [:outer_brain, "outer_brain"] do
      {:error, {:out_of_scope_owner, owner_scope}}
    else
      :ok
    end
  end

  defp required(attrs, fields) do
    case Enum.find(fields, &(not present?(value(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_optimization_artifact_ref, field}}
    end
  end

  defp has_key_deep?(attrs, key) when is_map(attrs) do
    Map.has_key?(attrs, key) or Enum.any?(Map.values(attrs), &has_key_deep?(&1, key))
  end

  defp has_key_deep?(items, key) when is_list(items),
    do: Enum.any?(items, &has_key_deep?(&1, key))

  defp has_key_deep?(_value, _key), do: false

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_list(value), do: value != []
  defp present?(value) when is_map(value), do: map_size(value) > 0
  defp present?(value), do: not is_nil(value)

  defp value!(attrs, field), do: value(attrs, field)
  defp value(attrs, field), do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
end
