defmodule OuterBrain.Contracts.SemanticGatewayContractTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.SemanticGatewayContract

  test "declares the Phase 6 M7 SemanticGatewayContract owner boundary" do
    contract = SemanticGatewayContract.contract()

    assert contract.id == "SemanticGatewayContract.v1"
    assert contract.owner == "outer_brain"
    assert contract.primary_repos == ["outer_brain", "stack_lab"]
    assert contract.phase6_milestone == "M7"
    assert contract.prelim_residual_ref == "P5P-002"

    assert contract.required_fields == [
             :semantic_context_provenance_ref,
             :semantic_failure_ref,
             :read_only_context_adapter_boundary_ref,
             :reply_publication_dedupe_ref,
             :suppression_visibility_ref,
             :privacy_redaction_fixture_ref,
             :restart_replay_with_semantic_state_ref
           ]

    assert :raw_prompt_or_provider_body_in_evidence in contract.forbidden
    assert :provider_sdk_local_mock_as_semantic_gateway_proof in contract.forbidden
    assert :lower_runtime_only_proof_without_outer_brain_owner_evidence in contract.forbidden
  end

  test "composes bounded owner evidence across the real OuterBrain semantic contracts" do
    assert {:ok, evidence} =
             SemanticGatewayContract.owner_evidence(SemanticGatewayContract.fixture())

    assert evidence.contract_id == "SemanticGatewayContract.v1"
    assert evidence.owner_repo == "outer_brain"
    assert evidence.real_outer_brain_surface? == true
    assert evidence.raw_payload_included? == false
    assert evidence.lower_runtime_only_proof? == false
    assert evidence.provider_sdk_mock_proof? == false

    assert evidence.semantic_context_provenance_ref == "semantic:result-phase6-m7"
    assert String.contains?(evidence.semantic_failure_ref, "semantic_failure_journal:v1:")
    assert evidence.read_only_context_adapter_boundary_ref == "context-adapter:phase6-m7"
    assert evidence.reply_publication_dedupe_ref == "causal-phase6-m7:final"
    assert evidence.suppression_visibility_ref == "suppression:phase6-m7"
    assert evidence.privacy_redaction_fixture_ref == "fixture:phase6-m7-privacy"

    assert evidence.restart_replay_with_semantic_state_ref ==
             "outer-brain-restart://phase6-m7/session/semantic-state-replayed"

    assert evidence.semantic_failure_classification == %{
             kind: :semantic_insufficient_context,
             retry_class: :clarification_required
           }

    assert evidence.reply_publication_dedupe == %{
             dedupe_key: "causal-phase6-m7:final",
             same_body_ref?: true,
             user_visible_publication_count: 1
           }

    assert evidence.suppression_visibility.operator_visibility == "visible"
    assert evidence.privacy_redaction.raw_field_name == "raw_provider_body"
    assert evidence.privacy_redaction.public_payload_keys == [:diagnostics_ref, :semantic_ref]

    assert evidence.bounded_evidence_refs == [
             "claim:semantic-input-phase6-m7",
             "claim:semantic-output-phase6-m7",
             "outer_brain.reply_publication:causal-phase6-m7:final:final:11a6767d5674c7e4"
           ]
  end

  test "fails closed when required semantic gateway evidence is missing" do
    required = [
      :semantic_context_provenance,
      :semantic_failure,
      :context_adapter_read_only,
      :reply_publication,
      :duplicate_suppression,
      :suppression_visibility,
      :privacy_redaction_fixture,
      :restart_replay_with_semantic_state_ref
    ]

    for field <- required do
      assert {:error, {:missing_required_semantic_gateway_evidence, ^field}} =
               SemanticGatewayContract.fixture()
               |> Map.delete(field)
               |> SemanticGatewayContract.owner_evidence()
    end
  end

  test "rejects raw payload, hidden suppression, mutable context adapters, and lower-only proofs" do
    assert {:error, {:raw_payload_forbidden, :raw_provider_body}} =
             SemanticGatewayContract.fixture()
             |> Map.put(:raw_provider_body, %{"text" => "raw provider body"})
             |> SemanticGatewayContract.owner_evidence()

    assert {:error, {:invalid_enum, :operator_visibility}} =
             SemanticGatewayContract.fixture()
             |> put_in([:suppression_visibility, :operator_visibility], "hidden")
             |> SemanticGatewayContract.owner_evidence()

    assert {:error, {:read_only_violation, :mutation_permissions}} =
             SemanticGatewayContract.fixture()
             |> put_in([:context_adapter_read_only, :mutation_permissions], ["write:workspace"])
             |> SemanticGatewayContract.owner_evidence()

    assert {:error, :lower_runtime_only_semantic_gateway_proof} =
             SemanticGatewayContract.fixture()
             |> Map.put(:real_outer_brain_surface?, false)
             |> Map.put(:lower_runtime_only_proof?, true)
             |> SemanticGatewayContract.owner_evidence()

    assert {:error, :provider_sdk_local_mock_semantic_gateway_proof} =
             SemanticGatewayContract.fixture()
             |> Map.put(:provider_sdk_mock_proof?, true)
             |> SemanticGatewayContract.owner_evidence()
  end
end
