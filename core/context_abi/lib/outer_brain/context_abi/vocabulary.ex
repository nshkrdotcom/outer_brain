defmodule OuterBrain.ContextABI.Vocabulary do
  @moduledoc """
  Bounded vocabulary for the Context ABI MVP.
  """

  @unit_kinds [
    :user_request,
    :system_instruction,
    :memory,
    :source_summary,
    :policy_summary,
    :eval_hint,
    :operator_note
  ]

  @trust_classes [
    :operator_authored,
    :system_policy,
    :tenant_policy,
    :source_connector,
    :workflow_receipt,
    :model_generated_unverified,
    :model_generated_verified,
    :memory_promoted,
    :memory_candidate,
    :external_untrusted
  ]

  @redaction_classes [:ref_only, :hash_ref, :bounded_excerpt, :redacted]

  @freshness_classes [:current, :recent, :stale, :unknown]

  def unit_kinds, do: @unit_kinds
  def trust_classes, do: @trust_classes
  def redaction_classes, do: @redaction_classes
  def freshness_classes, do: @freshness_classes
end
