defmodule OuterBrain.MemoryContractsTest do
  use ExUnit.Case, async: true

  alias OuterBrain.MemoryContracts

  test "write intents require tenant, authority, installation, idempotency, trace, redaction, and budget refs" do
    attrs = valid_write_intent()

    assert {:ok, intent} = MemoryContracts.write_intent(attrs)
    assert intent.tenant_ref == "tenant://a"

    for field <- [:tenant_ref, :authority_ref, :installation_ref, :idempotency_key, :trace_ref] do
      assert {:error, {:missing_required_ref, ^field}} =
               attrs
               |> Map.delete(field)
               |> MemoryContracts.write_intent()
    end
  end

  test "memory refs and evidence refs reject raw bodies" do
    assert {:error, {:raw_memory_body_forbidden, :body}} =
             valid_memory_ref()
             |> Map.put(:body, "raw")
             |> MemoryContracts.memory_ref()

    assert {:error, {:raw_memory_body_forbidden, "payload"}} =
             valid_evidence_ref()
             |> Map.put("payload", "raw")
             |> MemoryContracts.evidence_ref()
  end

  test "scope keys are bounded to declared refs" do
    assert {:ok, scope} = MemoryContracts.scope_key(valid_scope())
    assert scope.skill_ref == "skill://a"

    assert {:error, {:invalid_scope_ref, :run_ref}} =
             valid_scope()
             |> Map.put(:run_ref, :not_a_ref)
             |> MemoryContracts.scope_key()
  end

  test "redaction levels, access reasons, and budget decisions use bounded vocabularies" do
    assert {:ok, _policy} = MemoryContracts.redaction_policy(:hash_only)
    assert {:error, :invalid_memory_redaction_policy} = MemoryContracts.redaction_policy(:mask)

    assert {:ok, _reason} = MemoryContracts.access_reason(:hive_handoff)
    assert {:error, :unknown_memory_access_reason} = MemoryContracts.access_reason(:free_form)

    assert {:ok, _decision} =
             MemoryContracts.budget_decision(%{
               budget_ref: "budget://a",
               decision: :deny_exhausted,
               reason: :cumulative_overflow,
               requested_units: 10,
               granted_units: 0,
               residual_units: 0
             })

    assert {:error, :missing_budget_denial_reason} =
             MemoryContracts.budget_decision(%{
               budget_ref: "budget://a",
               decision: :deny_policy,
               requested_units: 10,
               granted_units: 0,
               residual_units: 0
             })
  end

  test "query intents reject raw query bodies and missing max results" do
    assert {:ok, intent} = MemoryContracts.query_intent(valid_query_intent())
    assert intent.max_results == 3

    assert {:error, {:raw_memory_body_forbidden, :content}} =
             valid_query_intent()
             |> Map.put(:content, "raw query")
             |> MemoryContracts.query_intent()

    assert {:error, {:invalid_field, :max_results}} =
             valid_query_intent()
             |> Map.put(:max_results, 0)
             |> MemoryContracts.query_intent()
  end

  defp valid_write_intent do
    %{
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      idempotency_key: "idem-1",
      trace_ref: "trace://a",
      scope_key: valid_scope(),
      content_class: "memory.note",
      content_hash: "sha256:abc",
      content_redacted_excerpt: "bounded",
      redaction_policy: %{level: :redacted_excerpt_only, redaction_policy_ref: "policy://redact"},
      ttl_class: "run",
      budget_ref: valid_budget_ref()
    }
  end

  defp valid_query_intent do
    %{
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      idempotency_key: "idem-2",
      trace_ref: "trace://a",
      scope_key: valid_scope(),
      query_class: "semantic",
      query_text_hash: "sha256:def",
      query_redacted_excerpt: "bounded query",
      redaction_policy: %{level: :hash_only, redaction_policy_ref: "policy://hash"},
      max_results: 3,
      budget_ref: valid_budget_ref()
    }
  end

  defp valid_memory_ref do
    %{
      memory_id: "mem-1",
      scope_key: valid_scope(),
      tier: :episodic,
      revision: 1,
      tenant_ref: "tenant://a"
    }
  end

  defp valid_evidence_ref do
    %{
      memory_id: "mem-1",
      evidence_hash: "sha256:abc",
      evidence_owner_ref: "owner://memory",
      release_manifest_ref: "release://a",
      redaction_policy_ref: "policy://redact"
    }
  end

  defp valid_scope do
    %{
      tenant_ref: "tenant://a",
      installation_ref: "installation://a",
      subject_ref: "subject://a",
      run_ref: "run://a",
      agent_ref: "agent://a",
      skill_ref: "skill://a"
    }
  end

  defp valid_budget_ref do
    %{
      budget_ref: "budget://a",
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      trace_ref: "trace://a"
    }
  end
end
