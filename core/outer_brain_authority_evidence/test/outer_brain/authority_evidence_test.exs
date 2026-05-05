defmodule OuterBrain.AuthorityEvidenceTest do
  use ExUnit.Case, async: true

  alias OuterBrain.AuthorityEvidence

  test "builds tenant-scoped ref-only prompt and memory authority evidence" do
    assert {:ok, evidence} = AuthorityEvidence.record(valid_evidence())

    assert evidence.tenant_ref == "tenant://tenant-1"
    assert evidence.prompt_provenance_ref == "prompt-provenance://tenant-1/turn-1"
    assert evidence.semantic_evidence_ref == "semantic-evidence://tenant-1/turn-1"
    assert evidence.memory_fact_refs == ["memory-fact://tenant-1/fact-1"]
    assert evidence.privacy_class == :tenant_private
    assert evidence.suppression_state == :visible
    assert evidence.raw_material_present? == false
  end

  test "rejects cross-tenant memory facts and raw prompt material" do
    assert {:error, {:cross_tenant_evidence_refs, refs}} =
             valid_evidence()
             |> Map.put(:memory_fact_refs, [
               "memory-fact://tenant-1/fact-1",
               "memory-fact://tenant-2/fact-9"
             ])
             |> AuthorityEvidence.record()

    assert refs == ["memory-fact://tenant-2/fact-9"]

    assert {:error, {:forbidden_authority_evidence_material, [:raw_prompt]}} =
             valid_evidence()
             |> Map.put(:raw_prompt, "secret prompt")
             |> AuthorityEvidence.record()
  end

  test "bounds privacy and suppression enums" do
    assert {:error, {:invalid_authority_evidence_enum, :privacy_class, :public_dump}} =
             valid_evidence()
             |> Map.put(:privacy_class, :public_dump)
             |> AuthorityEvidence.record()

    assert {:error, {:invalid_authority_evidence_enum, :suppression_state, :forgotten}} =
             valid_evidence()
             |> Map.put(:suppression_state, :forgotten)
             |> AuthorityEvidence.record()
  end

  defp valid_evidence do
    %{
      tenant_ref: "tenant://tenant-1",
      authority_packet_ref: "authority-packet://tenant-1/packet-1",
      prompt_provenance_ref: "prompt-provenance://tenant-1/turn-1",
      semantic_evidence_ref: "semantic-evidence://tenant-1/turn-1",
      memory_fact_refs: ["memory-fact://tenant-1/fact-1"],
      redaction_ref: "redaction://tenant-1/outer-brain/1",
      trace_ref: "trace://tenant-1/outer-brain/1",
      privacy_class: :tenant_private,
      suppression_state: :visible
    }
  end
end
