defmodule OuterBrain.GuardrailContracts do
  @moduledoc """
  Guardrail contract validators and structs.
  """

  alias OuterBrain.PromptFabric

  @payload_kinds [:input_prompt, :tool_input, :tool_output, :provider_response, :memory_candidate]
  @decision_classes [
    :allow,
    :allow_with_redaction,
    :block,
    :escalate,
    :deny_policy,
    :deny_detector_unavailable
  ]
  @redaction_postures [:pass, :partial, :excerpt_only, :no_export, :block]
  @severities [:info, :warn, :block, :escalate]
  @remediation_classes [:none, :redact, :retry_with_policy, :operator_review, :reject]
  @raw_payload_keys [
    :body,
    :raw_body,
    :payload,
    :raw_payload,
    :prompt_body,
    :provider_payload,
    "body",
    "raw_body",
    "payload",
    "raw_payload",
    "prompt_body",
    "provider_payload"
  ]

  defmodule DetectorRef do
    @moduledoc "Detector ref."
    @enforce_keys [:detector_ref, :detector_class, :version_ref]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            detector_ref: String.t(),
            detector_class: atom(),
            version_ref: String.t()
          }
  end

  defmodule DetectorOutcome do
    @moduledoc "Detector outcome."
    @enforce_keys [:detector_ref, :severity, :redaction_posture, :decision_class]
    defstruct [:bounded_excerpt, :violation_class | @enforce_keys]

    @type t :: %__MODULE__{
            detector_ref: DetectorRef.t(),
            severity: atom(),
            redaction_posture: atom(),
            decision_class: atom(),
            bounded_excerpt: String.t() | nil,
            violation_class: String.t() | nil
          }
  end

  defmodule GuardrailViolation do
    @moduledoc "Guardrail violation ref."
    @enforce_keys [
      :violation_id,
      :detector_ref,
      :severity,
      :violation_class,
      :bounded_redacted_excerpt,
      :evidence_ref,
      :remediation_class
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            violation_id: String.t(),
            detector_ref: DetectorRef.t(),
            severity: atom(),
            violation_class: String.t(),
            bounded_redacted_excerpt: String.t(),
            evidence_ref: String.t(),
            remediation_class: atom()
          }
  end

  defmodule GuardrailDecision do
    @moduledoc "Guardrail decision."
    @enforce_keys [
      :tenant_ref,
      :authority_ref,
      :installation_ref,
      :idempotency_key,
      :trace_ref,
      :prompt_ref,
      :payload_kind,
      :detector_chain_ref,
      :decision_class,
      :redaction_posture,
      :operator_action
    ]
    defstruct [:detector_outcomes, :violations | @enforce_keys]

    @type t :: %__MODULE__{
            tenant_ref: String.t(),
            authority_ref: String.t(),
            installation_ref: String.t(),
            idempotency_key: String.t(),
            trace_ref: String.t(),
            prompt_ref: PromptFabric.PromptArtifactRef.t(),
            payload_kind: atom(),
            detector_chain_ref: String.t(),
            decision_class: atom(),
            redaction_posture: atom(),
            operator_action: atom(),
            detector_outcomes: [DetectorOutcome.t()],
            violations: [GuardrailViolation.t()]
          }
  end

  @type detector_ref :: DetectorRef.t()
  @type detector_outcome :: DetectorOutcome.t()
  @type guardrail_violation :: GuardrailViolation.t()
  @type guardrail_decision :: GuardrailDecision.t()

  @spec payload_kinds() :: [atom()]
  def payload_kinds, do: @payload_kinds

  @spec decision_classes() :: [atom()]
  def decision_classes, do: @decision_classes

  @spec redaction_postures() :: [atom()]
  def redaction_postures, do: @redaction_postures

  @spec guardrail_decision(map()) :: {:ok, GuardrailDecision.t()} | {:error, term()}
  def guardrail_decision(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         :ok <-
           required_strings(attrs, [
             :tenant_ref,
             :authority_ref,
             :installation_ref,
             :idempotency_key,
             :trace_ref,
             :detector_chain_ref,
             :operator_action
           ]),
         {:ok, prompt_ref} <- attrs |> fetch(:prompt_ref) |> PromptFabric.artifact_ref(),
         {:ok, payload_kind} <-
           member(attrs, :payload_kind, @payload_kinds, :unknown_guard_payload_kind),
         {:ok, decision_class} <-
           member(attrs, :decision_class, @decision_classes, :unknown_guard_decision_class),
         {:ok, redaction_posture} <-
           member(attrs, :redaction_posture, @redaction_postures, :unknown_redaction_posture) do
      {:ok,
       %GuardrailDecision{
         tenant_ref: fetch!(attrs, :tenant_ref),
         authority_ref: fetch!(attrs, :authority_ref),
         installation_ref: fetch!(attrs, :installation_ref),
         idempotency_key: fetch!(attrs, :idempotency_key),
         trace_ref: fetch!(attrs, :trace_ref),
         prompt_ref: prompt_ref,
         payload_kind: payload_kind,
         detector_chain_ref: fetch!(attrs, :detector_chain_ref),
         decision_class: decision_class,
         redaction_posture: redaction_posture,
         operator_action: fetch!(attrs, :operator_action),
         detector_outcomes: List.wrap(fetch(attrs, :detector_outcomes, [])),
         violations: List.wrap(fetch(attrs, :violations, []))
       }}
    end
  end

  @spec guardrail_violation(map()) :: {:ok, GuardrailViolation.t()} | {:error, term()}
  def guardrail_violation(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         :ok <-
           required_strings(attrs, [
             :violation_id,
             :violation_class,
             :bounded_redacted_excerpt,
             :evidence_ref
           ]),
         {:ok, detector_ref} <- attrs |> fetch(:detector_ref) |> detector_ref(),
         {:ok, severity} <- member(attrs, :severity, @severities, :unknown_guard_severity),
         {:ok, remediation_class} <-
           member(
             attrs,
             :remediation_class,
             @remediation_classes,
             :unknown_guard_remediation_class
           ) do
      {:ok,
       %GuardrailViolation{
         violation_id: fetch!(attrs, :violation_id),
         detector_ref: detector_ref,
         severity: severity,
         violation_class: fetch!(attrs, :violation_class),
         bounded_redacted_excerpt: fetch!(attrs, :bounded_redacted_excerpt),
         evidence_ref: fetch!(attrs, :evidence_ref),
         remediation_class: remediation_class
       }}
    end
  end

  @spec detector_ref(map()) :: {:ok, DetectorRef.t()} | {:error, term()}
  def detector_ref(attrs) when is_map(attrs) do
    with :ok <- required_strings(attrs, [:detector_ref, :version_ref]) do
      {:ok,
       %DetectorRef{
         detector_ref: fetch!(attrs, :detector_ref),
         detector_class: fetch(attrs, :detector_class, :reference),
         version_ref: fetch!(attrs, :version_ref)
       }}
    end
  end

  @spec detector_outcome(map()) :: {:ok, DetectorOutcome.t()} | {:error, term()}
  def detector_outcome(attrs) when is_map(attrs) do
    with {:ok, detector_ref} <- attrs |> fetch(:detector_ref) |> detector_ref(),
         {:ok, severity} <- member(attrs, :severity, @severities, :unknown_guard_severity),
         {:ok, posture} <-
           member(attrs, :redaction_posture, @redaction_postures, :unknown_redaction_posture),
         {:ok, decision} <-
           member(attrs, :decision_class, @decision_classes, :unknown_guard_decision_class) do
      {:ok,
       %DetectorOutcome{
         detector_ref: detector_ref,
         severity: severity,
         redaction_posture: posture,
         decision_class: decision,
         bounded_excerpt: fetch(attrs, :bounded_excerpt),
         violation_class: fetch(attrs, :violation_class)
       }}
    end
  end

  @spec stricter_posture(atom(), atom()) :: {:ok, atom()} | {:error, term()}
  def stricter_posture(left, right)
      when left in @redaction_postures and right in @redaction_postures do
    left_index = Enum.find_index(@redaction_postures, &(&1 == left))
    right_index = Enum.find_index(@redaction_postures, &(&1 == right))
    {:ok, Enum.at(@redaction_postures, max(left_index, right_index))}
  end

  def stricter_posture(_left, _right), do: {:error, :unknown_redaction_posture}

  defp reject_raw_payload(attrs) do
    case Enum.find(@raw_payload_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_guardrail_payload_forbidden, key}}
    end
  end

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(not present_string?(fetch(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_guardrail_ref, field}}
    end
  end

  defp member(attrs, field, allowed, error) do
    value = fetch(attrs, field)
    if value in allowed, do: {:ok, value}, else: {:error, error}
  end

  defp present_string?(value) when is_binary(value), do: String.trim(value) != ""
  defp present_string?(_value), do: false

  defp fetch!(attrs, field), do: fetch(attrs, field)
  defp fetch(attrs, field), do: fetch(attrs, field, nil)

  defp fetch(attrs, field, default),
    do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field)) || default
end
