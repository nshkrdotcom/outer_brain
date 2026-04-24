defmodule OuterBrain.Contracts.MemoryContextProvenanceTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.MemoryContextProvenance

  test "v2 provenance carries recall proof, snapshot epoch, source node, and ordering evidence" do
    assert {:ok, provenance} = MemoryContextProvenance.new(valid_attrs())

    assert provenance.contract_name == "OuterBrain.MemoryContextProvenance.v2"
    assert provenance.semantic_ref == "semantic://context/1"
    assert provenance.recall_proof_token_ref == "proof://recall/1"
    assert provenance.snapshot_epoch == 42
    assert provenance.source_node_ref == "node://memory-reader@host/reader-1"
    assert provenance.commit_lsn == "16/B374D848"

    assert provenance.commit_hlc == %{
             wall_ns: 1_800_000_000_000_000_000,
             logical: 1,
             node: "reader-1"
           }

    assert MemoryContextProvenance.to_map(provenance).recall_proof_token_ref ==
             "proof://recall/1"
  end

  test "v2 provenance rejects missing recall proof and invalid snapshot epoch" do
    assert {:error, {:missing_field, :recall_proof_token_ref}} =
             valid_attrs()
             |> Map.delete(:recall_proof_token_ref)
             |> MemoryContextProvenance.new()

    assert {:error, {:invalid_field, :snapshot_epoch}} =
             valid_attrs()
             |> Map.put(:snapshot_epoch, 0)
             |> MemoryContextProvenance.new()
  end

  defp valid_attrs do
    %{
      tenant_id: "tenant://alpha",
      tenant_ref: "tenant://alpha",
      installation_ref: "installation://alpha",
      workspace_ref: "workspace://alpha",
      project_ref: "project://memory",
      environment_ref: "environment://test",
      resource_ref: "resource://recall-context",
      authority_packet_ref: "authority://packet",
      permission_decision_ref: "permission://decision",
      idempotency_key: "memory-context-v2-1",
      trace_id: "trace-recall-alpha",
      correlation_id: "correlation://recall-alpha",
      release_manifest_ref: "release://phase7",
      semantic_session_id: "semantic-session://1",
      causal_unit_id: "turn://1",
      request_trace_id: "trace-recall-alpha",
      principal_ref: "user://alpha",
      system_actor_ref: "agent://alpha",
      semantic_ref: "semantic://context/1",
      provider_ref: "provider://outer-brain",
      model_ref: "model://memory-context",
      prompt_hash: "sha256:prompt",
      context_hash: "sha256:context",
      input_claim_check_ref: "claim://input",
      output_claim_check_ref: "claim://output",
      provenance_refs: ["provenance://adapter"],
      normalizer_version: "memory-v2",
      redaction_policy_ref: "redaction://default",
      recall_proof_token_ref: "proof://recall/1",
      snapshot_epoch: 42,
      source_node_ref: "node://memory-reader@host/reader-1",
      commit_lsn: "16/B374D848",
      commit_hlc: %{wall_ns: 1_800_000_000_000_000_000, logical: 1, node: "reader-1"}
    }
  end
end
