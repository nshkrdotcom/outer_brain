defmodule OuterBrain.AIArtifactContracts.Vocabulary do
  @moduledoc false

  @common_ref_fields [
    :tenant_ref,
    :artifact_graph_ref,
    :trace_ref,
    :redaction_policy_ref
  ]

  @ref_set_fields [
    :prompt_artifact_ref,
    :role_pack_ref,
    :skill_ref,
    :gepa_component_ref,
    :candidate_ref,
    :candidate_delta_ref,
    :objective_ref,
    :optimization_run_ref,
    :eval_suite_ref,
    :eval_run_ref,
    :replay_bundle_ref,
    :router_artifact_ref,
    :router_decision_ref,
    :verifier_artifact_ref,
    :provider_pool_ref,
    :model_profile_ref,
    :endpoint_profile_ref,
    :promotion_ref,
    :rollback_ref
  ]

  @policy_artifact_fields [
    :artifact_ref,
    :artifact_kind,
    :tenant_ref,
    :source_ref,
    :lineage_ref,
    :rollback_ref,
    :trace_ref,
    :redaction_policy_ref
  ]

  @raw_keys [
    :body,
    :raw_body,
    :prompt_body,
    :raw_prompt,
    :provider_payload,
    :raw_provider_payload,
    :payload,
    :raw_payload,
    :memory_body,
    :model_output,
    :tool_input,
    :tool_output,
    :credential_body,
    :api_key,
    :authorization_header,
    "body",
    "raw_body",
    "prompt_body",
    "raw_prompt",
    "provider_payload",
    "raw_provider_payload",
    "payload",
    "raw_payload",
    "memory_body",
    "model_output",
    "tool_input",
    "tool_output",
    "credential_body",
    "api_key",
    "authorization_header"
  ]

  @policy_artifact_kinds [
    :prompt_policy,
    :role_pack,
    :tool_policy,
    :retrieval_policy,
    :router_policy,
    :verifier_artifact
  ]

  @spec common_ref_fields() :: [atom()]
  def common_ref_fields, do: @common_ref_fields

  @spec ref_set_fields() :: [atom()]
  def ref_set_fields, do: @ref_set_fields

  @spec policy_artifact_fields() :: [atom()]
  def policy_artifact_fields, do: @policy_artifact_fields

  @spec raw_keys() :: [atom() | String.t()]
  def raw_keys, do: @raw_keys

  @spec policy_artifact_kinds() :: [atom()]
  def policy_artifact_kinds, do: @policy_artifact_kinds
end
