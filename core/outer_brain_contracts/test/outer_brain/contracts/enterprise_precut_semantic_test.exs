defmodule OuterBrain.Contracts.EnterprisePrecutSemanticTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.{
    ContextHash,
    ProvenanceRef,
    SemanticActivityInput,
    SemanticDuplicateSuppressionMetadata,
    SemanticFailureCarrier,
    SemanticRedaction,
    SemanticResultRef,
    SourcePrecedence
  }

  @modules [
    SemanticActivityInput,
    SemanticResultRef,
    SemanticFailureCarrier,
    ContextHash,
    ProvenanceRef,
    SemanticDuplicateSuppressionMetadata,
    SemanticRedaction,
    SourcePrecedence
  ]

  test "loads every M24 semantic contract module" do
    for module <- @modules do
      assert Code.ensure_loaded?(module), "#{inspect(module)} is not compiled"
    end
  end

  test "semantic activity input consumes enterprise pre-cut scope" do
    assert {:ok, input} =
             SemanticActivityInput.new(%{
               tenant_ref: "tenant-acme",
               actor_ref: "principal-operator",
               resource_ref: "resource-work-1",
               workflow_ref: "wf-110",
               activity_call_ref: "act-115",
               authority_packet_ref: "authpkt-115",
               permission_decision_ref: "decision-115",
               trace_id: "trace-115",
               idempotency_key: "idem-semantic-115",
               context_ref: "context-115",
               context_hash: String.duplicate("a", 64),
               expected_schema_version: "v1",
               normalization_policy_ref: "normalizer-policy-1",
               redaction_posture: "operator_summary"
             })

    assert input.contract_name == "OuterBrain.SemanticActivityInput.v1"
  end

  test "semantic result refs include provenance and bounded routing facts" do
    assert {:ok, _context_hash} =
             ContextHash.new(%{
               context_hash: String.duplicate("a", 64),
               tenant_ref: "tenant-acme",
               semantic_session_id: "semantic-session-1",
               trace_id: "trace-115"
             })

    assert {:ok, provenance_ref} =
             ProvenanceRef.new(%{
               provenance_ref: "prov-1",
               tenant_ref: "tenant-acme",
               source_ref: "source-1",
               source_precedence: "authoritative",
               trace_id: "trace-115"
             })

    assert {:ok, result} =
             SemanticResultRef.new(%{
               semantic_ref: "semantic-115",
               semantic_session_id: "semantic-session-1",
               context_hash: String.duplicate("a", 64),
               provenance_refs: [provenance_ref.provenance_ref],
               validation_state: "coerced_valid",
               normalized_summary_ref: "summary-115",
               diagnostics_ref: "diagnostics-115",
               routing_facts: %{"review_required" => false, "semantic_score" => 0.92},
               result_hash: String.duplicate("b", 64),
               failure_class: "none",
               retry_posture: "none",
               redaction_posture: "operator_summary",
               trace_id: "trace-115"
             })

    assert result.routing_facts["semantic_score"] == 0.92
  end

  test "failure, duplicate suppression, redaction, and source precedence are explicit" do
    assert {:ok, _failure} =
             SemanticFailureCarrier.new(%{
               semantic_ref: "semantic-115",
               tenant_ref: "tenant-acme",
               failure_class: "semantic_provenance_missing",
               retry_posture: "human_review",
               diagnostics_ref: "diagnostics-115",
               provenance_refs: [],
               trace_id: "trace-115"
             })

    assert {:ok, _suppression} =
             SemanticDuplicateSuppressionMetadata.new(%{
               tenant_ref: "tenant-acme",
               semantic_ref: "semantic-115",
               idempotency_key: "idem-semantic-115",
               dedupe_scope: "tenant-acme:semantic-context-115",
               publication_ref: "publication-115",
               trace_id: "trace-115"
             })

    assert {:ok, _redaction} =
             SemanticRedaction.new(%{
               tenant_ref: "tenant-acme",
               semantic_ref: "semantic-115",
               redaction_posture: "operator_summary",
               diagnostics_ref: "diagnostics-115",
               trace_id: "trace-115"
             })

    assert {:ok, _precedence} =
             SourcePrecedence.new(%{
               tenant_ref: "tenant-acme",
               semantic_ref: "semantic-115",
               source_ref: "source-1",
               precedence_class: "authoritative",
               trace_id: "trace-115"
             })
  end
end
