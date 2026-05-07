defmodule OuterBrain.AIArtifactContractsTest do
  use ExUnit.Case, async: true

  alias OuterBrain.AIArtifactContracts

  test "AOC-011 artifact ref set is ref-only and covers adaptive artifact families" do
    assert {:ok, ref_set} = AIArtifactContracts.build_ref_set(ref_set_attrs())

    assert ref_set.prompt_artifact_ref.prompt_artifact_ref == "prompt://artifact/a"
    assert ref_set.role_pack_ref.role_pack_ref == "role-pack://coordinator/a"
    assert ref_set.skill_ref.owner_scope == :outer_brain
    assert ref_set.candidate_ref.parent_candidate_refs == ["candidate://parent"]
    assert ref_set.router_artifact_ref.router_artifact_ref == "router-artifact://a"
    assert ref_set.verifier_artifact_ref.verifier_artifact_ref == "verifier://a"
    assert ref_set.promotion_ref.rollback_ref == "rollback://a"

    projection = AIArtifactContracts.to_projection(ref_set)

    assert projection.redacted == true
    refute Map.has_key?(projection, :raw_prompt)
    refute Map.has_key?(projection, :provider_payload)
    refute Map.has_key?(projection, :memory_body)
    refute Map.has_key?(projection, :model_output)
  end

  test "artifact refs reject raw payload fields and out-of-scope skill ownership" do
    assert {:error, {:raw_ai_artifact_payload_forbidden, :raw_prompt}} =
             ref_set_attrs()
             |> Map.put(:raw_prompt, "raw prompt")
             |> AIArtifactContracts.build_ref_set()

    assert {:error, {:out_of_scope_owner, :external_skill_runtime}} =
             ref_set_attrs()
             |> put_in([:skill_ref, :owner_scope], :external_skill_runtime)
             |> AIArtifactContracts.build_ref_set()
  end

  test "AOC-012 policy artifacts carry lineage and rollback refs without raw bodies" do
    assert {:ok, artifact} = AIArtifactContracts.policy_artifact_ref(policy_artifact_attrs())

    assert artifact.artifact_kind == :tool_policy
    assert artifact.lineage_ref == "lineage://tool-policy/a"
    assert artifact.rollback_ref == "rollback://tool-policy/a"
    assert artifact.source_ref == "prompt://artifact/a"

    assert {:error, {:raw_ai_artifact_payload_forbidden, :raw_provider_payload}} =
             policy_artifact_attrs()
             |> Map.put(:raw_provider_payload, "raw")
             |> AIArtifactContracts.policy_artifact_ref()
  end

  defp ref_set_attrs do
    %{
      tenant_ref: "tenant://a",
      artifact_graph_ref: "artifact-graph://a",
      prompt_artifact_ref: "prompt://artifact/a",
      role_pack_ref: "role-pack://coordinator/a",
      skill_ref: %{skill_ref: "skill://capability/a", owner_scope: :outer_brain},
      gepa_component_ref: "gepa-component://prompt/a",
      candidate_ref: %{
        candidate_ref: "candidate://a",
        parent_candidate_refs: ["candidate://parent"],
        objective_ref: "objective://quality",
        checkpoint_ref: "checkpoint://a"
      },
      candidate_delta_ref: "candidate-delta://a",
      objective_ref: "objective://quality",
      optimization_run_ref: "optimization-run://a",
      eval_suite_ref: "eval-suite://a",
      eval_run_ref: "eval-run://a",
      replay_bundle_ref: "replay-bundle://a",
      router_artifact_ref: "router-artifact://a",
      router_decision_ref: "router-decision://a",
      verifier_artifact_ref: "verifier://a",
      provider_pool_ref: "provider-pool://a",
      model_profile_ref: "model-profile://a",
      endpoint_profile_ref: "endpoint-profile://a",
      promotion_ref: %{promotion_ref: "promotion://a", rollback_ref: "rollback://a"},
      rollback_ref: "rollback://a",
      trace_ref: "trace://a",
      redaction_policy_ref: "redaction://a"
    }
  end

  defp policy_artifact_attrs do
    %{
      artifact_ref: "policy-artifact://tool/a",
      artifact_kind: :tool_policy,
      tenant_ref: "tenant://a",
      source_ref: "prompt://artifact/a",
      lineage_ref: "lineage://tool-policy/a",
      rollback_ref: "rollback://tool-policy/a",
      trace_ref: "trace://policy/a",
      redaction_policy_ref: "redaction://policy/a"
    }
  end
end
