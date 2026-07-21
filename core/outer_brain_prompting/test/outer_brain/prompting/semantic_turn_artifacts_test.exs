defmodule OuterBrain.Prompting.SemanticTurnArtifactsTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Prompting.{ImmutableArtifact, SemanticTurnArtifacts}

  test "prompt artifacts are deterministic, distinct, and ref-only" do
    attrs = prompt_attrs("deterministic")

    assert {:ok, first} = SemanticTurnArtifacts.prepare_prompt(attrs)
    assert {:ok, second} = SemanticTurnArtifacts.prepare_prompt(attrs)

    assert first == second

    assert first.context_artifact.descriptor.content_digest !=
             first.prompt_artifact.descriptor.content_digest

    assert first.provenance.prompt_hash == first.prompt_artifact.descriptor.content_digest
    assert first.provenance.context_hash == first.context_artifact.descriptor.content_digest
    assert first.prompt_artifact.descriptor.artifact_ref in first.provenance.provenance_refs
    assert first.context_artifact.descriptor.artifact_ref in first.provenance.provenance_refs
    refute first.prompt_artifact.payload =~ "system instructions"
    refute first.prompt_artifact.payload =~ "user prompt"
  end

  test "prompt construction requires pinned sources and explicit artifact access" do
    assert {:error, :prompt_source_artifacts_required} =
             SemanticTurnArtifacts.prepare_prompt(%{
               prompt_attrs("missing-source")
               | source_artifacts: [
                   %{
                     artifact_ref: "artifact://synapse/user",
                     content_digest: "sha256:" <> String.duplicate("1", 64),
                     role: "user_input"
                   }
                 ]
             })

    assert {:error, :artifact_access_scope_required} =
             SemanticTurnArtifacts.prepare_prompt(%{
               prompt_attrs("missing-access")
               | allowed_reader_refs: []
             })
  end

  test "final reply is normalized into immutable reply and continuation artifacts" do
    {:ok, prompt} = SemanticTurnArtifacts.prepare_prompt(prompt_attrs("reply"))

    assert {:ok, continuation} =
             SemanticTurnArtifacts.prepare_reply(prompt, %{
               attempt_ref: "attempt://jido/gemini/reply",
               assistant_reply: "A bounded final reply.",
               dedupe_key: "turn://synapse/reply/1:final",
               published_at: ~U[2026-07-21 08:00:00Z],
               allowed_reader_refs: ["reader://synapse"],
               allowed_operation_refs: ["operation://synapse/read"]
             })

    assert continuation.reply_artifact.payload == "A bounded final reply."
    assert continuation.previous_semantic_ref == prompt.provenance.semantic_ref
    assert continuation.next_provenance.semantic_ref != prompt.provenance.semantic_ref

    assert continuation.reply_artifact.descriptor.artifact_ref in continuation.next_provenance.provenance_refs

    refute inspect(continuation.reply_artifact) =~ "A bounded final reply."
    assert inspect(continuation.reply_artifact) =~ "[REDACTED ARTIFACT PAYLOAD]"
  end

  test "secret-shaped final text is rejected" do
    {:ok, prompt} = SemanticTurnArtifacts.prepare_prompt(prompt_attrs("secret"))

    assert {:error, :invalid_reply_continuation} =
             SemanticTurnArtifacts.prepare_reply(prompt, %{
               attempt_ref: "attempt://jido/gemini/secret",
               assistant_reply: "Authorization: Bearer must-not-persist",
               dedupe_key: "turn://synapse/secret/1:final",
               published_at: ~U[2026-07-21 08:00:00Z],
               allowed_reader_refs: ["reader://synapse"],
               allowed_operation_refs: ["operation://synapse/read"]
             })
  end

  test "immutable JSON artifacts reject private reasoning keys" do
    assert {:error, {:private_reasoning_artifact_key, "chain_of_thought"}} =
             ImmutableArtifact.json(
               "context",
               %{"chain_of_thought" => "must-not-persist"},
               immutable_attrs("private-reasoning")
             )
  end

  defp prompt_attrs(suffix) do
    %{
      tenant_ref: "tenant://outer-brain/test",
      installation_ref: "installation://synapse/#{suffix}",
      workspace_ref: "workspace://synapse/#{suffix}",
      project_ref: "project://synapse/#{suffix}",
      environment_ref: "environment://synapse/test",
      authority_packet_ref: "authority-packet://gemini/#{suffix}",
      permission_decision_ref: "decision://citadel/#{suffix}",
      idempotency_key: "idempotency://synapse/#{suffix}",
      trace_id: "trace://synapse/#{suffix}",
      correlation_id: "correlation://synapse/#{suffix}",
      release_manifest_ref: "release://nshkr/p03",
      input_claim_check_ref: "claim-check://synapse/#{suffix}/input",
      output_claim_check_ref: "claim-check://synapse/#{suffix}/output",
      redaction_policy_ref: "redaction-policy://nshkr/p03",
      normalizer_version: "outer-brain-normalizer-v1",
      run_ref: "run://synapse/#{suffix}",
      turn_ref: "turn://synapse/#{suffix}/1",
      model_profile_ref: "model-profile://nshkr/gemini-2.5-flash",
      provider_ref: "provider://google/gemini",
      model_ref: "model://google/gemini-2.5-flash",
      producing_operation_ref: "operation://outer-brain/context/#{suffix}",
      system_actor_ref: "actor://nshkr/outer-brain",
      source_artifacts: [
        %{
          artifact_ref: "artifact://synapse/#{suffix}/system-instruction",
          content_digest: "sha256:" <> String.duplicate("1", 64),
          role: "system_instruction"
        },
        %{
          artifact_ref: "artifact://synapse/#{suffix}/user-input",
          content_digest: "sha256:" <> String.duplicate("2", 64),
          role: "user_input"
        }
      ],
      memory_snapshot_refs: ["memory-snapshot://outer-brain/#{suffix}"],
      allowed_reader_refs: ["reader://synapse"],
      allowed_operation_refs: ["operation://synapse/read"]
    }
  end

  defp immutable_attrs(suffix) do
    %{
      tenant_ref: "tenant://outer-brain/test",
      authority_packet_ref: "authority-packet://gemini/#{suffix}",
      producing_operation_ref: "operation://outer-brain/context/#{suffix}",
      allowed_reader_refs: ["reader://synapse"],
      allowed_operation_refs: ["operation://synapse/read"],
      provenance: %{"artifact_role" => "context"},
      retention: %{"policy_ref" => "retention://outer-brain/test"}
    }
  end
end
