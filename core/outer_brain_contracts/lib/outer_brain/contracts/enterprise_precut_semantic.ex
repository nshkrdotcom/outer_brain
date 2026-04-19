defmodule OuterBrain.Contracts.EnterprisePrecutSemanticSupport do
  @moduledoc false

  @spec build(module(), String.t(), [atom()], [atom()], map() | keyword(), keyword()) ::
          {:ok, struct()} | {:error, term()}
  def build(module, contract_name, fields, required_fields, attrs, opts \\ []) do
    with {:ok, attrs} <- normalize_attrs(attrs),
         [] <- missing_required_fields(attrs, required_fields),
         :ok <- validate_lists(attrs, Keyword.get(opts, :list_fields, [])),
         :ok <- validate_maps(attrs, Keyword.get(opts, :map_fields, [])) do
      {:ok, struct(module, attrs |> Map.take(fields) |> Map.put(:contract_name, contract_name))}
    else
      fields when is_list(fields) -> {:error, {:missing_required_fields, fields}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp normalize_attrs(attrs) when is_list(attrs), do: {:ok, Map.new(attrs)}

  defp normalize_attrs(attrs) when is_map(attrs) do
    if Map.has_key?(attrs, :__struct__), do: {:ok, Map.from_struct(attrs)}, else: {:ok, attrs}
  end

  defp normalize_attrs(_attrs), do: {:error, :invalid_attrs}

  defp missing_required_fields(attrs, required_fields) do
    Enum.reject(required_fields, &present?(Map.get(attrs, &1)))
  end

  defp validate_lists(attrs, fields) do
    if Enum.all?(fields, &is_list(Map.get(attrs, &1, []))) do
      :ok
    else
      {:error, :invalid_list_field}
    end
  end

  defp validate_maps(attrs, fields) do
    if Enum.all?(fields, &is_map(Map.get(attrs, &1, %{}))) do
      :ok
    else
      {:error, :invalid_map_field}
    end
  end

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_list(value), do: value != []
  defp present?(value) when is_map(value), do: map_size(value) > 0
  defp present?(value), do: not is_nil(value)
end

defmodule OuterBrain.Contracts.SemanticActivityInput do
  @moduledoc "Semantic activity input metadata consumed by Mezzanine workflows."

  alias OuterBrain.Contracts.EnterprisePrecutSemanticSupport

  @fields [
    :contract_name,
    :tenant_ref,
    :actor_ref,
    :resource_ref,
    :workflow_ref,
    :activity_call_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :trace_id,
    :idempotency_key,
    :context_ref,
    :context_hash,
    :expected_schema_version,
    :normalization_policy_ref,
    :redaction_posture
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSemanticSupport.build(
        __MODULE__,
        "OuterBrain.SemanticActivityInput.v1",
        @fields,
        [
          :tenant_ref,
          :actor_ref,
          :resource_ref,
          :workflow_ref,
          :activity_call_ref,
          :permission_decision_ref,
          :trace_id,
          :idempotency_key,
          :context_ref,
          :context_hash,
          :expected_schema_version,
          :normalization_policy_ref,
          :redaction_posture
        ],
        attrs
      )
end

defmodule OuterBrain.Contracts.SemanticResultRef do
  @moduledoc "Workflow-safe semantic result reference and routing-facts contract."

  alias OuterBrain.Contracts.EnterprisePrecutSemanticSupport

  @fields [
    :contract_name,
    :semantic_ref,
    :semantic_session_id,
    :context_hash,
    :provenance_refs,
    :validation_state,
    :normalized_summary_ref,
    :diagnostics_ref,
    :routing_facts,
    :result_hash,
    :failure_class,
    :retry_posture,
    :redaction_posture,
    :trace_id
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSemanticSupport.build(
        __MODULE__,
        "OuterBrain.SemanticResultRef.v1",
        @fields,
        [
          :semantic_ref,
          :semantic_session_id,
          :context_hash,
          :provenance_refs,
          :validation_state,
          :normalized_summary_ref,
          :diagnostics_ref,
          :routing_facts,
          :result_hash,
          :failure_class,
          :retry_posture,
          :redaction_posture,
          :trace_id
        ],
        attrs,
        list_fields: [:provenance_refs],
        map_fields: [:routing_facts]
      )
end

defmodule OuterBrain.Contracts.SemanticFailureCarrier do
  @moduledoc "Semantic failure carrier that preserves provenance and diagnostics refs."

  alias OuterBrain.Contracts.EnterprisePrecutSemanticSupport

  @fields [
    :contract_name,
    :semantic_ref,
    :tenant_ref,
    :failure_class,
    :retry_posture,
    :diagnostics_ref,
    :provenance_refs,
    :trace_id
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSemanticSupport.build(
        __MODULE__,
        "OuterBrain.SemanticFailureCarrier.v1",
        @fields,
        [:semantic_ref, :tenant_ref, :failure_class, :retry_posture, :diagnostics_ref, :trace_id],
        attrs,
        list_fields: [:provenance_refs]
      )
end

defmodule OuterBrain.Contracts.ContextHash do
  @moduledoc "Hash reference for semantic context bodies stored outside workflow history."

  alias OuterBrain.Contracts.EnterprisePrecutSemanticSupport

  @fields [:contract_name, :context_hash, :tenant_ref, :semantic_session_id, :trace_id]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSemanticSupport.build(
        __MODULE__,
        "OuterBrain.ContextHash.v1",
        @fields,
        [:context_hash, :tenant_ref, :semantic_session_id, :trace_id],
        attrs
      )
end

defmodule OuterBrain.Contracts.ProvenanceRef do
  @moduledoc "Public-safe semantic provenance reference."

  alias OuterBrain.Contracts.EnterprisePrecutSemanticSupport

  @fields [
    :contract_name,
    :provenance_ref,
    :tenant_ref,
    :source_ref,
    :source_precedence,
    :trace_id
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSemanticSupport.build(
        __MODULE__,
        "OuterBrain.ProvenanceRef.v1",
        @fields,
        [:provenance_ref, :tenant_ref, :source_ref, :source_precedence, :trace_id],
        attrs
      )
end

defmodule OuterBrain.Contracts.SemanticDuplicateSuppressionMetadata do
  @moduledoc "Semantic publication duplicate-suppression metadata."

  alias OuterBrain.Contracts.EnterprisePrecutSemanticSupport

  @fields [
    :contract_name,
    :tenant_ref,
    :semantic_ref,
    :idempotency_key,
    :dedupe_scope,
    :publication_ref,
    :trace_id
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSemanticSupport.build(
        __MODULE__,
        "OuterBrain.SemanticDuplicateSuppressionMetadata.v1",
        @fields,
        [
          :tenant_ref,
          :semantic_ref,
          :idempotency_key,
          :dedupe_scope,
          :publication_ref,
          :trace_id
        ],
        attrs
      )
end

defmodule OuterBrain.Contracts.SemanticRedaction do
  @moduledoc "Semantic result redaction posture metadata."

  alias OuterBrain.Contracts.EnterprisePrecutSemanticSupport

  @fields [
    :contract_name,
    :tenant_ref,
    :semantic_ref,
    :redaction_posture,
    :diagnostics_ref,
    :trace_id
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSemanticSupport.build(
        __MODULE__,
        "OuterBrain.SemanticRedaction.v1",
        @fields,
        [:tenant_ref, :semantic_ref, :redaction_posture, :diagnostics_ref, :trace_id],
        attrs
      )
end

defmodule OuterBrain.Contracts.SourcePrecedence do
  @moduledoc "Source-precedence reference used by semantic normalization."

  alias OuterBrain.Contracts.EnterprisePrecutSemanticSupport

  @fields [
    :contract_name,
    :tenant_ref,
    :semantic_ref,
    :source_ref,
    :precedence_class,
    :trace_id
  ]
  defstruct @fields

  @type t :: %__MODULE__{}

  def new(attrs),
    do:
      EnterprisePrecutSemanticSupport.build(
        __MODULE__,
        "OuterBrain.SourcePrecedence.v1",
        @fields,
        [:tenant_ref, :semantic_ref, :source_ref, :precedence_class, :trace_id],
        attrs
      )
end
