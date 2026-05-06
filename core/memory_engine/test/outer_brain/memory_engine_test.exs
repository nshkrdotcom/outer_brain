defmodule OuterBrain.MemoryEngineTest do
  use ExUnit.Case, async: true

  alias OuterBrain.MemoryEngine

  test "memory writes return refs and evidence without raw bodies" do
    store = MemoryEngine.new()

    assert {:ok, store, memory_ref, evidence_ref} =
             MemoryEngine.write(store, write_intent(), "raw memory body")

    assert memory_ref.memory_id
    assert evidence_ref.evidence_hash
    assert {:ok, projection} = MemoryEngine.project(store, memory_ref)
    assert projection.redacted_excerpt == "raw memory body"
    refute Map.has_key?(projection, :body)
    refute Map.has_key?(projection, :raw_body)
  end

  test "oversize memory bodies are replaced by hash evidence" do
    assert {:ok, store, memory_ref, _evidence_ref} =
             MemoryEngine.write(MemoryEngine.new(), write_intent(), "abcdef", max_export_bytes: 3)

    assert {:ok, projection} = MemoryEngine.project(store, memory_ref)
    assert projection.redacted_excerpt == "body_oversize_replaced_by_hash_ref"
  end

  test "cross-tenant and cross-installation reads fail closed" do
    assert {:ok, store, _memory_ref, _evidence_ref} =
             MemoryEngine.write(MemoryEngine.new(), write_intent(), "tenant a")

    assert {:ok, []} =
             MemoryEngine.query(
               store,
               query_intent(%{tenant_ref: "tenant://b", installation_ref: "installation://a"})
             )

    assert {:ok, []} =
             MemoryEngine.query(
               store,
               query_intent(%{tenant_ref: "tenant://a", installation_ref: "installation://b"})
             )
  end

  test "durable adapter selection is rejected when the adapter is not registered" do
    store = MemoryEngine.new(adapter: :postgres)

    assert {:error, {:unregistered_memory_adapter, :postgres}} =
             MemoryEngine.write(store, write_intent(), "body")
  end

  test "evicted memory does not replay through query" do
    assert {:ok, store, memory_ref, _evidence_ref} =
             MemoryEngine.write(MemoryEngine.new(), write_intent(), "body")

    assert {:ok, store, receipt} = MemoryEngine.evict(store, memory_ref, :operator_evicted)
    assert receipt.eviction_reason == :operator_evicted
    assert {:ok, []} = MemoryEngine.query(store, query_intent())
  end

  defp write_intent(overrides \\ %{}) do
    Map.merge(
      %{
        tenant_ref: "tenant://a",
        authority_ref: "authority://a",
        installation_ref: "installation://a",
        idempotency_key: "idem-write",
        trace_ref: "trace://a",
        scope_key: scope(),
        content_class: "note",
        content_hash: "sha256:body",
        content_redacted_excerpt: "body",
        redaction_policy: %{
          level: :redacted_excerpt_only,
          redaction_policy_ref: "policy://redact"
        },
        ttl_class: "run",
        budget_ref: budget_ref()
      },
      overrides
    )
  end

  defp query_intent(overrides \\ %{}) do
    Map.merge(
      %{
        tenant_ref: "tenant://a",
        authority_ref: "authority://a",
        installation_ref: "installation://a",
        idempotency_key: "idem-query",
        trace_ref: "trace://a",
        scope_key: scope(),
        query_class: "semantic",
        query_text_hash: "sha256:query",
        query_redacted_excerpt: "query",
        redaction_policy: %{level: :hash_only, redaction_policy_ref: "policy://hash"},
        max_results: 10,
        budget_ref: budget_ref()
      },
      overrides
    )
  end

  defp scope do
    %{
      tenant_ref: "tenant://a",
      installation_ref: "installation://a",
      subject_ref: "subject://a",
      run_ref: "run://a",
      agent_ref: "agent://a",
      skill_ref: "skill://a"
    }
  end

  defp budget_ref do
    %{
      budget_ref: "budget://a",
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      trace_ref: "trace://a"
    }
  end
end
