defmodule OuterBrain.ContextABI.ContextUnit do
  @moduledoc """
  Ref-only unit of candidate context for Context ABI packets.
  """

  alias OuterBrain.ContextABI.{Failure, Validator, Vocabulary}

  @schema_ref "outer_brain.context_unit.mvp.v1"

  @enforce_keys [
    :schema_ref,
    :context_unit_ref,
    :tenant_ref,
    :unit_kind,
    :artifact_ref,
    :source_ref,
    :trust_class,
    :redaction_class,
    :trace_ref
  ]

  defstruct [
    :schema_ref,
    :context_unit_ref,
    :tenant_ref,
    :unit_kind,
    :artifact_ref,
    :source_ref,
    :trust_class,
    :redaction_class,
    :trace_ref,
    metadata: %{}
  ]

  @type unit_kind ::
          :user_request
          | :system_instruction
          | :memory
          | :source_summary
          | :policy_summary
          | :eval_hint
          | :operator_note

  @type t :: %__MODULE__{
          schema_ref: String.t(),
          context_unit_ref: String.t(),
          tenant_ref: String.t(),
          unit_kind: unit_kind(),
          artifact_ref: String.t(),
          source_ref: String.t(),
          trust_class: atom(),
          redaction_class: atom(),
          trace_ref: String.t(),
          metadata: map()
        }

  @spec new(map() | keyword() | t()) :: {:ok, t()} | {:error, Failure.t()}
  def new(%__MODULE__{} = unit), do: {:ok, unit}
  def new(attrs) when is_list(attrs), do: attrs |> Map.new() |> new()

  def new(attrs) when is_map(attrs) do
    with :ok <- Validator.reject_raw_payload(attrs),
         {:ok, context_unit_ref} <- Validator.required_string(attrs, :context_unit_ref),
         {:ok, tenant_ref} <- Validator.required_string(attrs, :tenant_ref),
         {:ok, unit_kind} <-
           Validator.member(
             attrs,
             :unit_kind,
             Vocabulary.unit_kinds(),
             "outer_brain.context.invalid_unit_kind.v1"
           ),
         {:ok, artifact_ref} <- Validator.required_string(attrs, :artifact_ref),
         {:ok, source_ref} <- Validator.required_string(attrs, :source_ref),
         {:ok, trust_class} <-
           Validator.member(
             attrs,
             :trust_class,
             Vocabulary.trust_classes(),
             "outer_brain.context.invalid_trust_class.v1"
           ),
         {:ok, redaction_class} <-
           Validator.member(
             attrs,
             :redaction_class,
             Vocabulary.redaction_classes(),
             "outer_brain.context.invalid_redaction_class.v1"
           ),
         {:ok, trace_ref} <- Validator.required_string(attrs, :trace_ref),
         {:ok, metadata} <- Validator.optional_map(attrs, :metadata) do
      {:ok,
       %__MODULE__{
         schema_ref: Validator.fetch(attrs, :schema_ref, @schema_ref),
         context_unit_ref: context_unit_ref,
         tenant_ref: tenant_ref,
         unit_kind: unit_kind,
         artifact_ref: artifact_ref,
         source_ref: source_ref,
         trust_class: trust_class,
         redaction_class: redaction_class,
         trace_ref: trace_ref,
         metadata: metadata
       }}
    end
  end

  def new(_attrs) do
    Validator.failure(:outer_brain, "outer_brain.context.invalid_unit.v1",
      safe_message: "context unit is invalid"
    )
  end
end
