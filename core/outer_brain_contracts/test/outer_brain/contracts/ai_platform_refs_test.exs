defmodule OuterBrain.Contracts.AIPlatformRefsTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.AIPlatformRefs

  test "prompt and guard refs are ref-only bounded contracts" do
    assert {:ok, prompt_ref} = AIPlatformRefs.prompt_artifact_ref(prompt_ref())
    assert prompt_ref.prompt_id == "prompt://a"

    assert {:ok, lineage_ref} = AIPlatformRefs.prompt_lineage_ref(lineage_ref())
    assert lineage_ref.derivation_reason == :author

    assert {:ok, guard_ref} = AIPlatformRefs.guard_decision_ref(guard_decision_ref())
    assert guard_ref.decision_class == :block

    assert {:ok, chain_ref} = AIPlatformRefs.guard_chain_ref(guard_chain_ref())
    assert chain_ref.redaction_posture_floor == :partial
  end

  test "AI platform refs reject raw prompt and guard payload fields" do
    assert {:error, {:raw_ai_platform_ref_payload_forbidden, :prompt_body}} =
             prompt_ref()
             |> Map.put(:prompt_body, "raw")
             |> AIPlatformRefs.prompt_artifact_ref()

    assert {:error, {:raw_ai_platform_ref_payload_forbidden, :guard_payload}} =
             guard_decision_ref()
             |> Map.put(:guard_payload, "raw")
             |> AIPlatformRefs.guard_decision_ref()
  end

  test "eval replay and drift refs carry bounded classes without raw payloads" do
    assert {:ok, suite} = AIPlatformRefs.eval_suite_ref(eval_suite_ref())
    assert suite.eval_suite_ref == "eval-suite://a"

    assert {:ok, run} = AIPlatformRefs.eval_run_ref(eval_run_ref())
    assert run.verdict == :regress

    assert {:ok, divergence} = AIPlatformRefs.replay_divergence_ref(replay_divergence_ref())
    assert divergence.phase == :guard_decision

    assert {:ok, signal} = AIPlatformRefs.drift_signal_ref(drift_signal_ref())
    assert signal.signal_class == :latency_drift

    assert {:error, {:raw_ai_platform_ref_payload_forbidden, :model_output}} =
             eval_run_ref()
             |> Map.put(:model_output, "raw")
             |> AIPlatformRefs.eval_run_ref()

    assert {:error, {:invalid_ai_platform_ref, :signal_class}} =
             drift_signal_ref()
             |> Map.put(:signal_class, :free_form)
             |> AIPlatformRefs.drift_signal_ref()
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

  defp lineage_ref do
    %{
      lineage_ref: "prompt-lineage://a/1",
      prompt_id: "prompt://a",
      revision: 1,
      derivation_reason: :author,
      decision_evidence_ref: "decision://prompt"
    }
  end

  defp guard_decision_ref do
    %{
      guard_decision_ref: "guard-decision://a",
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      trace_ref: "trace://a",
      detector_chain_ref: "guard-chain://a",
      decision_class: :block,
      redaction_posture: :block
    }
  end

  defp guard_chain_ref do
    %{
      guard_chain_ref: "guard-chain://a",
      tenant_ref: "tenant://a",
      installation_ref: "installation://a",
      policy_revision_ref: "policy-revision://a",
      detector_refs: ["detector://pii-reference"],
      redaction_posture_floor: :partial
    }
  end

  defp eval_suite_ref do
    %{
      eval_suite_ref: "eval-suite://a",
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      release_manifest_ref: "release://phase-c"
    }
  end

  defp eval_run_ref do
    %{
      eval_run_ref: "eval-run://a",
      eval_suite_ref: "eval-suite://a",
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      trace_ref: "trace://eval",
      verdict: :regress
    }
  end

  defp replay_divergence_ref do
    %{
      replay_divergence_ref: "replay-divergence://a",
      source_trace_ref: "trace://source",
      replay_trace_ref: "trace://replay",
      phase: :guard_decision,
      severity: :regress,
      redaction_policy_ref: "redaction://replay"
    }
  end

  defp drift_signal_ref do
    %{
      drift_signal_ref: "drift-signal://a",
      tenant_ref: "tenant://a",
      installation_ref: "installation://a",
      signal_class: :latency_drift,
      window_ref: "drift-window://a"
    }
  end
end
