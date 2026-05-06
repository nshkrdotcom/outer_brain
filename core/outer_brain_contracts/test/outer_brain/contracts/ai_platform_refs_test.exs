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
end
