defmodule OuterBrain.MemoryContracts.Vocabulary do
  @moduledoc false

  @raw_payload_keys [
    :body,
    :raw_body,
    :content,
    :raw_content,
    :payload,
    :raw_payload,
    "body",
    "raw_body",
    "content",
    "raw_content",
    "payload",
    "raw_payload"
  ]

  @required_refs [
    :tenant_ref,
    :authority_ref,
    :installation_ref,
    :idempotency_key,
    :trace_ref
  ]

  @redaction_levels [
    :unrestricted,
    :redacted_excerpt_only,
    :hash_only,
    :no_export
  ]

  @memory_tiers [:episodic, :semantic, :working]

  @access_reasons [
    :prompt_grounding,
    :tool_grounding,
    :eval_replay,
    :operator_inspect,
    :audit_recovery,
    :skill_init,
    :hive_handoff
  ]

  @budget_decisions [
    :allow,
    :allow_with_redaction,
    :deny_oversize,
    :deny_exhausted,
    :deny_policy,
    :deny_revoked
  ]

  @budget_reasons [
    :prompt_overflow,
    :tool_overflow,
    :cumulative_overflow,
    :policy_denial,
    :operator_override_denied
  ]

  @spec raw_payload_keys() :: [atom() | String.t()]
  def raw_payload_keys, do: @raw_payload_keys

  @spec required_refs() :: [atom()]
  def required_refs, do: @required_refs

  @spec redaction_levels() :: [atom()]
  def redaction_levels, do: @redaction_levels

  @spec memory_tiers() :: [atom()]
  def memory_tiers, do: @memory_tiers

  @spec access_reasons() :: [atom()]
  def access_reasons, do: @access_reasons

  @spec budget_decisions() :: [atom()]
  def budget_decisions, do: @budget_decisions

  @spec budget_exhaustion_reasons() :: [atom()]
  def budget_exhaustion_reasons, do: @budget_reasons
end
