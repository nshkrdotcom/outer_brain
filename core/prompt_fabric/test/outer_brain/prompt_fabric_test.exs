defmodule OuterBrain.PromptFabricTest do
  use ExUnit.Case, async: true

  alias OuterBrain.PromptFabric

  test "prompt artifact refs reject missing refs and raw bodies" do
    assert {:error, {:missing_prompt_ref, :tenant_ref}} =
             valid_ref()
             |> Map.delete(:tenant_ref)
             |> PromptFabric.artifact_ref()

    assert {:error, {:raw_prompt_body_forbidden, :prompt_body}} =
             valid_ref()
             |> Map.put(:prompt_body, "raw prompt")
             |> PromptFabric.artifact_ref()
  end

  test "lineage and resolve decisions use bounded vocabularies" do
    assert {:ok, lineage} = PromptFabric.lineage_ref(valid_lineage())
    assert lineage.derivation_reason == :author

    assert {:error, :unknown_prompt_derivation_reason} =
             valid_lineage()
             |> Map.put(:derivation_reason, :free_form)
             |> PromptFabric.lineage_ref()

    assert {:error, :unknown_prompt_resolve_decision} =
             %{prompt_ref: valid_ref(), decision_class: :maybe, trace_ref: "trace://a"}
             |> PromptFabric.resolve_decision()
  end

  test "authoring creates immutable revisions with deterministic content hashes" do
    assert {:ok, store, first} =
             PromptFabric.author(PromptFabric.new(), author_attrs(), %{b: 2, a: 1})

    assert {:ok, _store, second} = PromptFabric.author(store, author_attrs(), %{a: 1, b: 2})

    assert first.revision == 1
    assert second.revision == 2
    assert first.content_hash == second.content_hash
  end

  test "rollback is forward only and cross-tenant rollback rejects" do
    assert {:ok, store, first} = PromptFabric.author(PromptFabric.new(), author_attrs(), "one")
    assert {:ok, store, _second} = PromptFabric.author(store, author_attrs(), "two")

    assert {:ok, _store, rollback_ref} =
             PromptFabric.rollback(
               store,
               Map.put(author_attrs(), :target_revision, first.revision)
             )

    assert rollback_ref.revision == 3

    assert {:error, :cross_tenant_prompt_reuse} =
             PromptFabric.rollback(
               store,
               author_attrs()
               |> Map.put(:tenant_ref, "tenant://other")
               |> Map.put(:target_revision, first.revision)
             )
  end

  test "A/B assignment is deterministic by tenant installation and assignment key" do
    assert {:ok, store, _first} = PromptFabric.author(PromptFabric.new(), author_attrs(), "one")
    assert {:ok, store, _second} = PromptFabric.author(store, author_attrs(), "two")

    attrs =
      author_attrs()
      |> Map.put(:variant_revisions, [1, 2])
      |> Map.put(:ab_assignment_key, "subject-1")

    assert {:ok, first} = PromptFabric.assign_ab(store, attrs)
    assert {:ok, second} = PromptFabric.assign_ab(store, attrs)
    assert first.revision == second.revision
  end

  test "projections are DTO-safe" do
    assert {:ok, store, ref} =
             PromptFabric.author(PromptFabric.new(), author_attrs(), "safe prompt")

    assert {:ok, projection} =
             PromptFabric.project(store, Map.merge(author_attrs(), %{revision: ref.revision}))

    assert projection.prompt_ref == ref
    refute Map.has_key?(projection, :prompt_body)
    refute Map.has_key?(projection, :raw_body)
  end

  defp valid_ref do
    %{
      prompt_id: "prompt://a",
      revision: 1,
      tenant_ref: "tenant://a",
      installation_ref: "installation://a",
      content_hash: "sha256:prompt",
      redaction_policy_ref: "redaction://prompt",
      lineage_ref: "prompt-lineage://a/1"
    }
  end

  defp valid_lineage do
    %{
      lineage_ref: "prompt-lineage://a/1",
      prompt_id: "prompt://a",
      revision: 1,
      derivation_reason: :author,
      decision_evidence_ref: "decision://a"
    }
  end

  defp author_attrs do
    %{
      tenant_ref: "tenant://a",
      authority_ref: "authority://a",
      installation_ref: "installation://a",
      idempotency_key: "idem-prompt",
      trace_ref: "trace://a",
      prompt_id: "prompt://a",
      redaction_policy_ref: "redaction://prompt",
      decision_evidence_ref: "decision://a"
    }
  end
end
