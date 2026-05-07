defmodule OuterBrain.Contracts.Phase4SemanticIntegrityContractsTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.{
    ContextAdapterReadOnly,
    NormalizedSemanticResult,
    Phase4SemanticContract,
    PrivacyRedactionFixture,
    SemanticActivityNormalized,
    SemanticContextProvenance,
    SemanticDuplicateSuppression,
    SuppressionVisibility
  }

  test "semantic context provenance requires full scope, claim-check refs, hashes, and redaction evidence" do
    assert {:ok, provenance} =
             SemanticContextProvenance.new(%{
               tenant_ref: "tenant:alpha",
               installation_ref: "installation:prod",
               workspace_ref: "workspace:ops",
               project_ref: "project:control-room",
               environment_ref: "environment:prod",
               system_actor_ref: "system:outer-brain",
               resource_ref: "semantic-context:ctx-1",
               authority_packet_ref: "authority:packet-1",
               permission_decision_ref: "permission:decision-1",
               idempotency_key: "semantic-context:ctx-1",
               trace_id: "trace-semantic-1",
               correlation_id: "correlation-semantic-1",
               release_manifest_ref: "phase4-v6-m7",
               semantic_ref: "semantic:result-1",
               provider_ref: "provider:anthropic",
               model_ref: "model:claude",
               prompt_hash: "sha256:prompt",
               context_hash: "sha256:context",
               input_claim_check_ref: "claim:input-1",
               output_claim_check_ref: "claim:output-1",
               provenance_refs: ["provenance:adapter-1", "provenance:normalizer-1"],
               normalizer_version: "outer-brain-normalizer@1",
               redaction_policy_ref: "redaction:semantic-public-v1"
             })

    assert provenance.contract_name == "OuterBrain.SemanticContextProvenance.v1"
    assert provenance.provenance_refs == ["provenance:adapter-1", "provenance:normalizer-1"]

    assert {:error, {:missing_field, :provenance_refs}} =
             provenance
             |> SemanticContextProvenance.to_map()
             |> Map.delete(:provenance_refs)
             |> SemanticContextProvenance.new()
  end

  test "duplicate suppression requires visible suppression evidence and deterministic duplicate lineage" do
    assert {:ok, suppression} =
             SemanticDuplicateSuppression.new(%{
               tenant_ref: "tenant:alpha",
               installation_ref: "installation:prod",
               workspace_ref: "workspace:ops",
               project_ref: "project:control-room",
               environment_ref: "environment:prod",
               principal_ref: "principal:operator-1",
               resource_ref: "semantic-publication:pub-1",
               authority_packet_ref: "authority:packet-2",
               permission_decision_ref: "permission:decision-2",
               idempotency_key: "semantic:dedupe-1",
               trace_id: "trace-semantic-2",
               correlation_id: "correlation-semantic-2",
               release_manifest_ref: "phase4-v6-m7",
               semantic_idempotency_key: "semantic-turn:dedupe-1",
               semantic_ref: "semantic:result-2",
               suppression_ref: "suppression:semantic-1",
               duplicate_of_ref: "semantic:result-1",
               routing_fact_hash: "sha256:routing-facts",
               publication_ref: "publication:pub-1",
               operator_visibility: "visible",
               reason_code: "duplicate_semantic_publication"
             })

    assert suppression.contract_name == "OuterBrain.SemanticDuplicateSuppression.v1"

    assert suppression.persistence_posture.persistence_profile_ref ==
             "persistence-profile://mickey-mouse"

    assert suppression.persistence_posture.raw_provider_payload_persistence? == false

    assert {:error, {:invalid_enum, :operator_visibility}} =
             suppression
             |> SemanticDuplicateSuppression.to_map()
             |> Map.put(:operator_visibility, "hidden")
             |> SemanticDuplicateSuppression.new()
  end

  test "context adapter descriptor is read only and rejects write grants" do
    assert {:ok, descriptor} =
             ContextAdapterReadOnly.new(%{
               tenant_ref: "tenant:alpha",
               installation_ref: "installation:prod",
               workspace_ref: "workspace:ops",
               project_ref: "project:control-room",
               environment_ref: "environment:prod",
               system_actor_ref: "system:outer-brain",
               resource_ref: "context-adapter:workspace-index",
               authority_packet_ref: "authority:packet-3",
               permission_decision_ref: "permission:decision-3",
               idempotency_key: "adapter:workspace-index:read-1",
               trace_id: "trace-semantic-3",
               correlation_id: "correlation-semantic-3",
               release_manifest_ref: "phase4-v6-m7",
               adapter_ref: "adapter:workspace-index",
               allowed_read_resources: ["workspace:ops", "project:control-room"],
               denied_write_resources: ["workspace:ops", "lower:*", "product:*"],
               read_claim_check_ref: "claim:context-read-1",
               mutation_scan_ref: "scan:adapter-read-only-1",
               mutation_permissions: []
             })

    assert descriptor.contract_name == "OuterBrain.ContextAdapterReadOnly.v1"

    assert {:error, {:read_only_violation, :mutation_permissions}} =
             descriptor
             |> ContextAdapterReadOnly.to_map()
             |> Map.put(:mutation_permissions, ["write:workspace"])
             |> ContextAdapterReadOnly.new()
  end

  test "normalized semantic activity exposes bounded routing facts without raw provider payloads" do
    assert {:ok, result} =
             SemanticActivityNormalized.new(%{
               tenant_ref: "tenant:alpha",
               installation_ref: "installation:prod",
               workspace_ref: "workspace:ops",
               project_ref: "project:control-room",
               environment_ref: "environment:prod",
               system_actor_ref: "system:outer-brain",
               resource_ref: "semantic-activity:activity-1",
               authority_packet_ref: "authority:packet-4",
               permission_decision_ref: "permission:decision-4",
               idempotency_key: "semantic-activity:activity-1",
               trace_id: "trace-semantic-4",
               correlation_id: "correlation-semantic-4",
               release_manifest_ref: "phase4-v6-m7",
               semantic_ref: "semantic:result-4",
               context_hash: "sha256:context",
               provenance_refs: ["provenance:adapter-1"],
               provider_ref: "provider:anthropic",
               model_ref: "model:claude",
               claim_check_refs: ["claim:prompt-1", "claim:provider-output-1"],
               normalized_summary: %{title: "Policy answer", body_ref: "summary:semantic-4"},
               routing_facts: %{
                 review_required: false,
                 semantic_score: 0.94,
                 confidence_band: "high",
                 risk_band: "low",
                 schema_validation_state: "valid",
                 normalization_warning_count: 0,
                 semantic_retry_class: "none",
                 terminal_class: "none",
                 review_reason_code: "none"
               },
               validation_state: :valid,
               diagnostics_ref: "diagnostics:semantic-4",
               retry_class: :none,
               terminal_class: :none,
               normalizer_version: "outer-brain-normalizer@1"
             })

    assert result.workflow_history_payload == %{
             semantic_ref: "semantic:result-4",
             context_hash: "sha256:context",
             provenance_refs: ["provenance:adapter-1"],
             validation_state: :valid,
             diagnostics_ref: "diagnostics:semantic-4",
             routing_facts: result.routing_facts,
             retry_class: :none,
             terminal_class: :none
           }

    assert {:error, {:raw_payload_forbidden, :raw_provider_body}} =
             result
             |> SemanticActivityNormalized.to_map()
             |> Map.put(:raw_provider_body, %{"text" => "raw llm body"})
             |> SemanticActivityNormalized.new()

    assert {:error, {:missing_routing_facts, [:risk_band]}} =
             result
             |> SemanticActivityNormalized.to_map()
             |> put_in([:routing_facts], Map.delete(result.routing_facts, :risk_band))
             |> SemanticActivityNormalized.new()

    assert {:error, :claim_check_only_routing_result} =
             SemanticActivityNormalized.new(%{
               semantic_ref: "semantic:claim-only",
               claim_check_refs: ["claim:provider-output-2"],
               routing_facts: %{}
             })
  end

  test "public nested maps normalize only known keys" do
    assert {:ok, normalized} =
             Phase4SemanticContract.required_map(
               %{
                 normalized_summary: %{
                   "title" => "Policy answer",
                   "body_ref" => "summary:semantic-4",
                   "ok" => "unknown keys stay strings"
                 }
               },
               :normalized_summary
             )

    assert normalized.title == "Policy answer"
    assert normalized.body_ref == "summary:semantic-4"
    assert normalized["ok"] == "unknown keys stay strings"
    refute Map.has_key?(normalized, :ok)
  end

  test "normalized semantic result exposes the M29 workflow payload boundary contract" do
    assert NormalizedSemanticResult.contract_name() ==
             "OuterBrain.SemanticActivityPayloadBoundary.v1"

    assert {:ok, result} = NormalizedSemanticResult.new(normalized_semantic_attrs())
    assert result.contract_name == "OuterBrain.SemanticActivityPayloadBoundary.v1"
    assert result.routing_facts.review_required == false
    refute Map.has_key?(result.workflow_history_payload, :normalized_summary)
    refute Map.has_key?(result.workflow_history_payload, :raw_provider_body)

    assert {:ok, history_payload} =
             NormalizedSemanticResult.workflow_history_payload(normalized_semantic_attrs())

    assert history_payload.contract_name == "OuterBrain.SemanticActivityPayloadBoundary.v1"
    assert history_payload.routing_facts.semantic_score == 0.94
  end

  test "normalization states separate diagnostics, review, recoverable failure, and quarantine" do
    assert SemanticActivityNormalized.quarantine_state?(:semantic_security_quarantine)
    assert SemanticActivityNormalized.quarantine_state?(:semantic_integrity_quarantine)
    refute SemanticActivityNormalized.quarantine_state?(:coerced_valid)
    refute SemanticActivityNormalized.quarantine_state?(:degraded_valid)
    refute SemanticActivityNormalized.quarantine_state?(:needs_human_review)

    assert :diagnostic ==
             SemanticActivityNormalized.classify_normalization_condition(:unknown_provider_keys)

    assert :diagnostic ==
             SemanticActivityNormalized.classify_normalization_condition(:safe_type_coercion)

    assert :review_or_reask ==
             SemanticActivityNormalized.classify_normalization_condition(:missing_optional_field)

    assert :quarantine ==
             SemanticActivityNormalized.classify_normalization_condition(:tenant_mismatch)

    assert :diagnostic ==
             NormalizedSemanticResult.classify_normalization_condition(:unknown_provider_keys)

    refute NormalizedSemanticResult.quarantine_state?(:low_confidence)
  end

  test "privacy redaction fixture forbids raw prompts, provider payloads, and search attribute leaks" do
    assert {:ok, fixture} =
             PrivacyRedactionFixture.new(%{
               tenant_ref: "tenant:alpha",
               installation_ref: "installation:prod",
               workspace_ref: "workspace:ops",
               project_ref: "project:control-room",
               environment_ref: "environment:prod",
               system_actor_ref: "system:outer-brain",
               resource_ref: "dto:semantic-summary",
               authority_packet_ref: "authority:packet-5",
               permission_decision_ref: "permission:decision-5",
               idempotency_key: "redaction:semantic-summary",
               trace_id: "trace-semantic-5",
               correlation_id: "correlation-semantic-5",
               release_manifest_ref: "phase4-v6-m7",
               redaction_policy_ref: "redaction:semantic-public-v1",
               raw_field_name: "raw_provider_body",
               public_field_name: "diagnostics_ref",
               redaction_class: "provider_payload",
               fixture_ref: "fixture:privacy-86",
               scan_ref: "scan:redaction-86",
               public_payload: %{
                 semantic_ref: "semantic:result-5",
                 diagnostics_ref: "diagnostics:semantic-5"
               },
               search_attributes: %{
                 "SemanticRef" => "semantic:result-5",
                 "TenantHash" => "sha256:tenant"
               }
             })

    assert fixture.contract_name == "Platform.PrivacyRedactionFixture.v1"

    assert {:error, {:public_payload_leak, :raw_provider_body}} =
             fixture
             |> PrivacyRedactionFixture.to_map()
             |> put_in([:public_payload, :raw_provider_body], "raw text")
             |> PrivacyRedactionFixture.new()

    assert {:error, {:search_attribute_leak, "RawPrompt"}} =
             fixture
             |> PrivacyRedactionFixture.to_map()
             |> put_in([:search_attributes, "RawPrompt"], "prompt text")
             |> PrivacyRedactionFixture.new()
  end

  test "suppression visibility contract requires operator-visible reason and recovery posture" do
    assert {:ok, visibility} =
             SuppressionVisibility.new(%{
               tenant_ref: "tenant:alpha",
               installation_ref: "installation:prod",
               workspace_ref: "workspace:ops",
               project_ref: "project:control-room",
               environment_ref: "environment:prod",
               system_actor_ref: "system:mezzanine",
               resource_ref: "suppression:semantic-1",
               authority_packet_ref: "authority:packet-6",
               permission_decision_ref: "permission:decision-6",
               idempotency_key: "suppression:semantic-1",
               trace_id: "trace-semantic-6",
               correlation_id: "correlation-semantic-6",
               release_manifest_ref: "phase4-v6-m7",
               suppression_ref: "suppression:semantic-1",
               suppression_kind: "duplicate",
               reason_code: "duplicate_semantic_publication",
               target_ref: "publication:pub-1",
               operator_visibility: "visible",
               recovery_action_refs: ["recovery:inspect-publication"],
               diagnostics_ref: "diagnostics:suppression-1"
             })

    assert visibility.contract_name == "Platform.SuppressionVisibility.v1"

    assert {:error, {:missing_field, :recovery_action_refs}} =
             visibility
             |> SuppressionVisibility.to_map()
             |> Map.put(:recovery_action_refs, [])
             |> SuppressionVisibility.new()
  end

  defp normalized_semantic_attrs do
    %{
      tenant_ref: "tenant:alpha",
      installation_ref: "installation:prod",
      workspace_ref: "workspace:ops",
      project_ref: "project:control-room",
      environment_ref: "environment:prod",
      system_actor_ref: "system:outer-brain",
      resource_ref: "semantic-activity:activity-1",
      authority_packet_ref: "authority:packet-4",
      permission_decision_ref: "permission:decision-4",
      idempotency_key: "semantic-activity:activity-1",
      trace_id: "trace-semantic-4",
      correlation_id: "correlation-semantic-4",
      release_manifest_ref: "phase4-v6-m29",
      semantic_ref: "semantic:result-4",
      context_hash: "sha256:context",
      provenance_refs: ["provenance:adapter-1"],
      provider_ref: "provider:anthropic",
      model_ref: "model:claude",
      claim_check_refs: ["claim:prompt-1", "claim:provider-output-1"],
      normalized_summary: %{title: "Policy answer", body_ref: "summary:semantic-4"},
      routing_facts: %{
        review_required: false,
        semantic_score: 0.94,
        confidence_band: "high",
        risk_band: "low",
        schema_validation_state: "valid",
        normalization_warning_count: 0,
        semantic_retry_class: "none",
        terminal_class: "none",
        review_reason_code: "none"
      },
      validation_state: :valid,
      diagnostics_ref: "diagnostics:semantic-4",
      retry_class: :none,
      terminal_class: :none,
      normalizer_version: "outer-brain-normalizer@1"
    }
  end
end
