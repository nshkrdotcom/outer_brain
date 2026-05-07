defmodule OuterBrain.OptimizationArtifactStoreTest do
  use ExUnit.Case, async: true

  alias OuterBrain.OptimizationArtifactStore

  test "AOC-012 records policy artifacts with lineage and rollback refs" do
    store = OptimizationArtifactStore.new()

    assert {:ok, store, artifact} =
             OptimizationArtifactStore.record_artifact(store, policy_artifact_attrs())

    assert artifact.artifact_kind == :router_policy
    assert artifact.lineage_ref == "lineage://router-policy/a"
    assert artifact.rollback_ref == "rollback://router-policy/a"

    assert {:ok, store, promotion} =
             OptimizationArtifactStore.record_promotion(store, promotion_attrs(artifact))

    assert promotion.source_artifact_refs == [artifact.artifact_ref]
    assert {:ok, projection} = OptimizationArtifactStore.project(store, promotion.promotion_ref)
    assert projection.redacted == true
    refute Map.has_key?(projection, :raw_prompt)
    refute Map.has_key?(projection, :provider_payload)
    refute Map.has_key?(projection, :memory_body)
    refute Map.has_key?(projection, :model_output)
  end

  test "artifact graph rejects raw bodies and out-of-scope owner placement" do
    assert {:error, {:raw_ai_artifact_payload_forbidden, :memory_body}} =
             OptimizationArtifactStore.new()
             |> OptimizationArtifactStore.record_artifact(
               Map.put(policy_artifact_attrs(), :memory_body, "raw")
             )

    assert {:error, {:out_of_scope_owner, :external_skill_runtime}} =
             OptimizationArtifactStore.new()
             |> OptimizationArtifactStore.record_artifact(
               Map.put(policy_artifact_attrs(), :owner_scope, :external_skill_runtime)
             )
  end

  defp policy_artifact_attrs do
    %{
      artifact_ref: "policy-artifact://router/a",
      artifact_kind: :router_policy,
      tenant_ref: "tenant://a",
      source_ref: "router-artifact://a",
      lineage_ref: "lineage://router-policy/a",
      rollback_ref: "rollback://router-policy/a",
      trace_ref: "trace://router-policy/a",
      redaction_policy_ref: "redaction://router-policy/a"
    }
  end

  defp promotion_attrs(artifact) do
    %{
      promotion_ref: "promotion://router-policy/a",
      tenant_ref: "tenant://a",
      source_artifact_refs: [artifact.artifact_ref],
      target_artifact_refs: ["router-artifact://production"],
      eval_evidence_refs: ["eval-run://a"],
      replay_bundle_ref: "replay-bundle://a",
      rollback_ref: "rollback://router-policy/a",
      trace_ref: "trace://promotion/a",
      redaction_policy_ref: "redaction://promotion/a"
    }
  end
end
