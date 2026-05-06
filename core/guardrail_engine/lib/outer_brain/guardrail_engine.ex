defmodule OuterBrain.GuardrailEngine do
  @moduledoc """
  Ordered guardrail detector-chain engine.
  """

  alias OuterBrain.GuardrailContracts

  @reference_detectors [
    :pii_reference,
    :jailbreak_reference,
    :schema_shape_reference,
    :length_bounds,
    :content_policy_reference
  ]
  @payload_kinds GuardrailContracts.payload_kinds()
  @terminal_decisions [:block, :escalate, :deny_policy, :deny_detector_unavailable]

  @spec reference_detectors() :: [atom()]
  def reference_detectors, do: @reference_detectors

  @spec evaluate(atom(), term(), map()) :: {:ok, struct()} | {:error, term()}
  def evaluate(payload_kind, payload, attrs)
      when payload_kind in @payload_kinds and is_map(attrs) do
    chain = List.wrap(Map.get(attrs, :detector_chain, []))

    with :ok <- declared_chain?(chain),
         :ok <- required_refs(attrs) do
      {outcomes, posture, decision_class} = run_chain(chain, payload, :pass, :allow)

      GuardrailContracts.guardrail_decision(%{
        tenant_ref: fetch!(attrs, :tenant_ref),
        authority_ref: fetch!(attrs, :authority_ref),
        installation_ref: fetch!(attrs, :installation_ref),
        idempotency_key: fetch!(attrs, :idempotency_key),
        trace_ref: fetch!(attrs, :trace_ref),
        prompt_ref: fetch!(attrs, :prompt_ref),
        payload_kind: payload_kind,
        detector_chain_ref: fetch!(attrs, :detector_chain_ref),
        decision_class: decision_class,
        redaction_posture: posture,
        operator_action: operator_action(decision_class),
        detector_outcomes: outcomes,
        violations: violations(outcomes)
      })
    end
  end

  def evaluate(payload_kind, _payload, _attrs),
    do: {:error, {:unknown_guard_payload_kind, payload_kind}}

  @spec project(struct()) :: map()
  def project(%GuardrailContracts.GuardrailDecision{} = decision) do
    %{
      tenant_ref: decision.tenant_ref,
      authority_ref: decision.authority_ref,
      installation_ref: decision.installation_ref,
      trace_ref: decision.trace_ref,
      prompt_ref: decision.prompt_ref,
      payload_kind: decision.payload_kind,
      detector_chain_ref: decision.detector_chain_ref,
      decision_class: decision.decision_class,
      redaction_posture: decision.redaction_posture,
      detector_outcomes: Enum.map(decision.detector_outcomes, &project_outcome/1),
      violations: Enum.map(decision.violations, &project_violation/1)
    }
  end

  defp run_chain(chain, payload, posture, decision_class) do
    Enum.reduce_while(chain, {[], posture, decision_class}, fn detector,
                                                               {outcomes, current_posture,
                                                                current_decision} ->
      {:ok, outcome} = evaluate_detector(detector, payload)

      {:ok, next_posture} =
        GuardrailContracts.stricter_posture(current_posture, outcome.redaction_posture)

      next_decision = stricter_decision(current_decision, outcome.decision_class)
      state = {outcomes ++ [outcome], next_posture, next_decision}

      if next_decision in @terminal_decisions do
        {:halt, state}
      else
        {:cont, state}
      end
    end)
  end

  defp evaluate_detector(:pii_reference, payload) do
    text = payload_text(payload)

    if String.contains?(text, "@") do
      outcome(:pii_reference, :block, :block, :block, "pii", bounded_excerpt(text))
    else
      outcome(:pii_reference, :info, :pass, :allow, nil, nil)
    end
  end

  defp evaluate_detector(:jailbreak_reference, payload) do
    text = String.downcase(payload_text(payload))

    if String.contains?(text, "ignore previous instructions") do
      outcome(:jailbreak_reference, :block, :block, :block, "jailbreak", bounded_excerpt(text))
    else
      outcome(:jailbreak_reference, :info, :pass, :allow, nil, nil)
    end
  end

  defp evaluate_detector(:schema_shape_reference, payload) do
    if is_binary(payload) or is_map(payload) do
      outcome(:schema_shape_reference, :info, :pass, :allow, nil, nil)
    else
      outcome(:schema_shape_reference, :block, :block, :block, "schema_shape", inspect(payload))
    end
  end

  defp evaluate_detector(:length_bounds, payload) do
    text = payload_text(payload)

    if byte_size(text) > 512 do
      outcome(
        :length_bounds,
        :warn,
        :excerpt_only,
        :allow_with_redaction,
        "length",
        bounded_excerpt(text)
      )
    else
      outcome(:length_bounds, :info, :pass, :allow, nil, nil)
    end
  end

  defp evaluate_detector(:content_policy_reference, payload) do
    text = String.downcase(payload_text(payload))

    if String.contains?(text, "disallowed-content") do
      outcome(
        :content_policy_reference,
        :escalate,
        :no_export,
        :escalate,
        "content_policy",
        bounded_excerpt(text)
      )
    else
      outcome(:content_policy_reference, :info, :pass, :allow, nil, nil)
    end
  end

  defp outcome(detector, severity, posture, decision, violation_class, excerpt) do
    GuardrailContracts.detector_outcome(%{
      detector_ref: detector_ref(detector),
      severity: severity,
      redaction_posture: posture,
      decision_class: decision,
      violation_class: violation_class,
      bounded_excerpt: excerpt
    })
  end

  defp violations(outcomes) do
    outcomes
    |> Enum.filter(&(&1.violation_class not in [nil, ""]))
    |> Enum.map(fn outcome ->
      {:ok, violation} =
        GuardrailContracts.guardrail_violation(%{
          violation_id:
            "guard-violation://#{outcome.detector_ref.detector_class}/#{hash(outcome.bounded_excerpt || "")}",
          detector_ref: Map.from_struct(outcome.detector_ref),
          severity: outcome.severity,
          violation_class: outcome.violation_class,
          bounded_redacted_excerpt: outcome.bounded_excerpt || "",
          evidence_ref: "guard-evidence://#{hash(outcome.violation_class || "")}",
          remediation_class: remediation(outcome.decision_class)
        })

      violation
    end)
  end

  defp declared_chain?([]), do: {:error, :missing_guard_detector_chain}

  defp declared_chain?(chain) do
    case Enum.find(chain, &(&1 not in @reference_detectors)) do
      nil -> :ok
      detector -> {:error, {:guard_detector_not_registered, detector}}
    end
  end

  defp required_refs(attrs) do
    fields = [
      :tenant_ref,
      :authority_ref,
      :installation_ref,
      :idempotency_key,
      :trace_ref,
      :prompt_ref,
      :detector_chain_ref
    ]

    case Enum.find(fields, &(fetch(attrs, &1) in [nil, ""])) do
      nil -> :ok
      field -> {:error, {:missing_guard_engine_ref, field}}
    end
  end

  defp stricter_decision(current, next) do
    cond do
      current in @terminal_decisions -> current
      next in @terminal_decisions -> next
      next == :allow_with_redaction -> :allow_with_redaction
      true -> current
    end
  end

  defp operator_action(:block), do: "reject"
  defp operator_action(:escalate), do: "operator_review"
  defp operator_action(:deny_policy), do: "reject"
  defp operator_action(:deny_detector_unavailable), do: "reject"
  defp operator_action(:allow_with_redaction), do: "redact"
  defp operator_action(:allow), do: "continue"

  defp remediation(:block), do: :reject
  defp remediation(:escalate), do: :operator_review
  defp remediation(:allow_with_redaction), do: :redact
  defp remediation(_decision), do: :none

  defp detector_ref(detector) do
    %{
      detector_ref: "detector://#{Atom.to_string(detector)}",
      detector_class: detector,
      version_ref: "detector-version://#{Atom.to_string(detector)}/v1"
    }
  end

  defp payload_text(value) when is_binary(value), do: value

  defp payload_text(value) when is_map(value),
    do: value |> Enum.map_join(" ", fn {key, inner} -> "#{key}=#{inner}" end)

  defp payload_text(value), do: inspect(value)

  defp bounded_excerpt(text), do: binary_part(text, 0, min(byte_size(text), 120))
  defp hash(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp project_outcome(outcome) do
    %{
      detector_ref: outcome.detector_ref.detector_ref,
      severity: outcome.severity,
      redaction_posture: outcome.redaction_posture,
      decision_class: outcome.decision_class,
      bounded_excerpt: outcome.bounded_excerpt
    }
  end

  defp project_violation(violation) do
    %{
      violation_id: violation.violation_id,
      detector_ref: violation.detector_ref.detector_ref,
      severity: violation.severity,
      violation_class: violation.violation_class,
      bounded_redacted_excerpt: violation.bounded_redacted_excerpt,
      evidence_ref: violation.evidence_ref,
      remediation_class: violation.remediation_class
    }
  end

  defp fetch!(attrs, field), do: fetch(attrs, field)
  defp fetch(attrs, field), do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
end
