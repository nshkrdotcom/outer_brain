defmodule OuterBrain.Contracts.SemanticFailureTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.SemanticFailure

  test "normalizes a provider-neutral semantic failure carrier" do
    assert {:ok, failure} =
             SemanticFailure.new(%{
               "kind" => "semantic_insufficient_context",
               "tenant_id" => "tenant-1",
               "semantic_session_id" => "session-1",
               "causal_unit_id" => "turn-1",
               "request_trace_id" => "trace-1",
               "provenance" => [%{"source" => "context_adapter"}],
               "context_hash" => "sha256:context",
               "provider_ref" => %{"provider" => "semantic-host"},
               "operator_message" => "Additional workspace context is required."
             })

    assert failure.kind == :semantic_insufficient_context
    assert failure.retry_class == :clarification_required
    assert failure.provenance == [%{"source" => "context_adapter"}]
    assert failure.provider_ref == %{"provider" => "semantic-host"}

    assert failure.persistence_posture.persistence_profile_ref ==
             "persistence-profile://mickey-mouse"

    assert failure.persistence_posture.raw_provider_payload_persistence? == false

    assert %{
             "kind" => "semantic_insufficient_context",
             "retry_class" => "clarification_required",
             "tenant_id" => "tenant-1",
             "semantic_session_id" => "session-1",
             "causal_unit_id" => "turn-1",
             "request_trace_id" => "trace-1",
             "substrate_trace_id" => nil,
             "provenance" => [%{"source" => "context_adapter"}],
             "context_hash" => "sha256:context",
             "canonical_idempotency_key" => nil,
             "idempotency_alias" => idempotency_alias,
             "provider_ref" => %{"provider" => "semantic-host"},
             "operator_message" => "Additional workspace context is required."
           } = SemanticFailure.to_payload(failure)

    assert String.starts_with?(idempotency_alias, "semantic_failure_idempotency_alias:v1:")

    assert {:ok, ^failure} =
             failure |> SemanticFailure.to_payload() |> SemanticFailure.from_payload()
  end

  test "durable semantic failure posture does not change journal identity" do
    memory = semantic_failure!()
    durable = semantic_failure!(persistence_profile: :durable_redacted)

    assert durable.persistence_posture.durable? == true
    assert durable.persistence_posture.raw_prompt_persistence? == false

    assert SemanticFailure.journal_identity_payload(memory) ==
             SemanticFailure.journal_identity_payload(durable)
  end

  test "derives structured hash journal identity from canonical semantic failure fields" do
    failure =
      semantic_failure!(
        substrate_trace_id: "substrate-trace-1",
        context_hash: "sha256:context",
        canonical_idempotency_key: "idem:v1:root",
        idempotency_alias: "semantic-turn-alias"
      )

    entry_id = SemanticFailure.journal_entry_id(failure)
    identity = SemanticFailure.journal_identity_payload(failure)
    payload_hash = SemanticFailure.semantic_failure_payload_hash(failure)

    assert String.starts_with?(entry_id, "semantic_failure_journal:v1:")
    assert entry_id != SemanticFailure.legacy_journal_entry_id(failure)
    assert byte_size(String.replace_prefix(entry_id, "semantic_failure_journal:v1:", "")) == 64

    assert identity["tenant_id"] == "tenant-semantic"
    assert identity["semantic_session_id"] == "session-semantic-1"
    assert identity["causal_unit_id"] == "turn-semantic-1"
    assert identity["kind"] == "semantic_insufficient_context"
    assert identity["request_trace_id"] == "trace-semantic-1"
    assert identity["substrate_trace_id"] == "substrate-trace-1"
    assert identity["context_hash"] == "sha256:context"
    assert identity["canonical_idempotency_key"] == "idem:v1:root"
    assert identity["idempotency_alias"] == nil
    assert identity["idempotency_ref"] == "idem:v1:root"
    assert identity["idempotency_ref_kind"] == "canonical_idempotency_key"
    assert identity["semantic_failure_payload_hash"] == payload_hash
    assert String.starts_with?(payload_hash, "sha256:")
  end

  test "uses a declared idempotency alias when no canonical key is present" do
    failure = semantic_failure!(idempotency_alias: "semantic-turn-alias")

    assert %{
             "canonical_idempotency_key" => nil,
             "idempotency_alias" => "semantic-turn-alias",
             "idempotency_ref" => "semantic-turn-alias",
             "idempotency_ref_kind" => "declared_alias"
           } = SemanticFailure.journal_identity_payload(failure)
  end

  test "payload hash distinguishes semantic failure payload changes" do
    first = semantic_failure!(operator_message: "The semantic host needs clarification.")
    changed = semantic_failure!(operator_message: "The semantic host needs a different repair.")

    assert SemanticFailure.semantic_failure_payload_hash(first) !=
             SemanticFailure.semantic_failure_payload_hash(changed)

    assert SemanticFailure.journal_entry_id(first) != SemanticFailure.journal_entry_id(changed)
  end

  test "keeps delimiter ids only as read-only legacy aliases" do
    failure = semantic_failure!()
    legacy_id = SemanticFailure.legacy_journal_entry_id(failure)

    assert legacy_id ==
             "semantic_failure:session-semantic-1:turn-semantic-1:semantic_insufficient_context"

    assert {:ok,
            %{
              "semantic_session_id" => "session-semantic-1",
              "causal_unit_id" => "turn-semantic-1",
              "kind" => "semantic_insufficient_context"
            }} = SemanticFailure.parse_legacy_journal_entry_id(legacy_id)

    assert %{
             "alias_type" => "read_only_legacy_semantic_failure_journal_id",
             "alias_id" => ^legacy_id,
             "canonical_entry_id" => canonical_entry_id,
             "source_ref" => "phase5-v7-m5-semantic-failure-journal-identity",
             "expires_after" => "legacy semantic failure journal migration",
             "parse_result" => %{"status" => "parseable"}
           } = SemanticFailure.legacy_journal_entry_alias(failure)

    assert canonical_entry_id == SemanticFailure.journal_entry_id(failure)
  end

  test "flags delimiter legacy ids as ambiguous while structured ids remain valid" do
    failure = semantic_failure!(semantic_session_id: "session:semantic:1")
    legacy_id = SemanticFailure.legacy_journal_entry_id(failure)

    assert {:error, :legacy_semantic_failure_journal_id_ambiguous} =
             SemanticFailure.parse_legacy_journal_entry_id(legacy_id)

    assert String.starts_with?(
             SemanticFailure.journal_entry_id(failure),
             "semantic_failure_journal:v1:"
           )
  end

  test "scans legacy ids for ambiguous parses and collisions" do
    parseable = SemanticFailure.legacy_journal_entry_id(semantic_failure!())

    ambiguous =
      SemanticFailure.legacy_journal_entry_id(semantic_failure!(causal_unit_id: "turn:1"))

    structured = SemanticFailure.journal_entry_id(semantic_failure!())

    assert %{
             "source_ref" => "phase5-v7-m5-semantic-failure-journal-identity",
             "legacy_ids" => legacy_ids,
             "non_legacy_ids" => non_legacy_ids,
             "ambiguous_legacy_ids" => ambiguous_ids,
             "duplicate_legacy_ids" => duplicate_ids
           } =
             SemanticFailure.legacy_journal_entry_id_scan([
               parseable,
               parseable,
               ambiguous,
               structured
             ])

    assert legacy_ids == [parseable, parseable, ambiguous]
    assert non_legacy_ids == [structured]
    assert ambiguous_ids == [ambiguous]
    assert duplicate_ids == [parseable]
  end

  test "rejects non-contract failure kinds and invalid provenance" do
    base = %{
      kind: :semantic_insufficient_context,
      tenant_id: "tenant-1",
      semantic_session_id: "session-1",
      causal_unit_id: "turn-1",
      request_trace_id: "trace-1",
      operator_message: "Need more context."
    }

    assert {:error, {:invalid_semantic_failure_kind, :provider_timeout}} =
             base
             |> Map.put(:kind, :provider_timeout)
             |> SemanticFailure.new()

    assert {:error, {:invalid_semantic_failure_kind, "provider_timeout"}} =
             base
             |> Map.put(:kind, "provider_timeout")
             |> SemanticFailure.new()

    assert {:error, :invalid_semantic_failure_provenance} =
             base
             |> Map.put(:provenance, %{"source" => "not-a-list"})
             |> SemanticFailure.new()
  end

  defp semantic_failure!(overrides \\ %{}) do
    attrs =
      %{
        kind: :semantic_insufficient_context,
        tenant_id: "tenant-semantic",
        semantic_session_id: "session-semantic-1",
        causal_unit_id: "turn-semantic-1",
        request_trace_id: "trace-semantic-1",
        provenance: [%{"source" => "semantic-host"}],
        operator_message: "The semantic host needs clarification."
      }
      |> Map.merge(Map.new(overrides))

    {:ok, failure} = SemanticFailure.new(attrs)
    failure
  end
end
