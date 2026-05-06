defmodule OuterBrain.GuardrailContractsTest do
  use ExUnit.Case, async: true

  alias OuterBrain.GuardrailContracts

  test "guardrail decisions require bounded refs and enums" do
    assert {:ok, decision} = GuardrailContracts.guardrail_decision(decision_attrs())
    assert decision.payload_kind == :input_prompt

    assert {:error, :unknown_guard_decision_class} =
             decision_attrs()
             |> Map.put(:decision_class, :maybe)
             |> GuardrailContracts.guardrail_decision()
  end

  test "violations reject raw payload and unknown severity or remediation" do
    assert {:ok, violation} = GuardrailContracts.guardrail_violation(violation_attrs())
    assert violation.severity == :block

    assert {:error, {:raw_guardrail_payload_forbidden, :payload}} =
             violation_attrs()
             |> Map.put(:payload, "raw")
             |> GuardrailContracts.guardrail_violation()

    assert {:error, :unknown_guard_severity} =
             violation_attrs()
             |> Map.put(:severity, :critical)
             |> GuardrailContracts.guardrail_violation()
  end

  test "detector outcomes require detector refs and posture is forward-only" do
    assert {:ok, _outcome} = GuardrailContracts.detector_outcome(outcome_attrs())

    assert {:error, {:missing_guardrail_ref, :detector_ref}} =
             outcome_attrs()
             |> put_in([:detector_ref, :detector_ref], "")
             |> GuardrailContracts.detector_outcome()

    assert {:ok, :no_export} = GuardrailContracts.stricter_posture(:partial, :no_export)
    assert {:ok, :block} = GuardrailContracts.stricter_posture(:block, :pass)
  end

  defp decision_attrs do
    %{
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      idempotency_key: "idem-guard",
      trace_ref: "trace://a",
      prompt_ref: prompt_ref(),
      payload_kind: :input_prompt,
      detector_chain_ref: "guard-chain://a",
      decision_class: :block,
      redaction_posture: :block,
      operator_action: "reject"
    }
  end

  defp violation_attrs do
    %{
      violation_id: "guard-violation://a",
      detector_ref: detector_ref(),
      severity: :block,
      violation_class: "policy",
      bounded_redacted_excerpt: "bounded",
      evidence_ref: "evidence://guard",
      remediation_class: :reject
    }
  end

  defp outcome_attrs do
    %{
      detector_ref: detector_ref(),
      severity: :warn,
      redaction_posture: :partial,
      decision_class: :allow_with_redaction
    }
  end

  defp detector_ref do
    %{
      detector_ref: "detector://length",
      detector_class: :length_bounds,
      version_ref: "version://1"
    }
  end

  defp prompt_ref do
    %{
      prompt_id: "prompt://a",
      revision: 1,
      tenant_ref: "tenant://a",
      installation_ref: "installation://a",
      content_hash: "sha256:prompt",
      redaction_policy_ref: "redaction://prompt",
      lineage_ref: "prompt-lineage://a/1"
    }
  end
end
