defmodule OuterBrain.Persistence.StoreTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL
  alias Ecto.Adapters.SQL.Sandbox
  alias OuterBrain.Contracts.Lease

  alias OuterBrain.Journal.Tables.{
    RecoveryTaskRecord,
    SemanticJournalEntryRecord
  }

  alias OuterBrain.Persistence.{ArtifactAccess, PostgresContainer, Repo, Store}
  alias OuterBrain.Persistence.Schemas.RecoveryTask, as: RecoveryTaskSchema
  alias OuterBrain.Prompting.SemanticTurnArtifacts

  @moduletag :tenant_isolation
  @tenant_a "tenant://outer-brain/a"
  @tenant_b "tenant://outer-brain/b"

  defmodule TemporaryRepo do
    use Ecto.Repo,
      otp_app: :outer_brain_persistence,
      adapter: Ecto.Adapters.Postgres
  end

  setup_all do
    container = PostgresContainer.start!("outer_brain_persistence")

    repo_config = PostgresContainer.repo_config(container.port)
    {:ok, _pid} = Repo.start_link(repo_config)

    PostgresContainer.run_migrations!(Repo)
    Sandbox.mode(Repo, :manual)

    on_exit(fn ->
      stop_repo_safely()
      PostgresContainer.stop!(container)
    end)

    {:ok, repo: Repo, repo_config: repo_config}
  end

  setup tags do
    if tags[:repo_restart] do
      Sandbox.mode(tags.repo, :auto)

      on_exit(fn ->
        if Process.whereis(tags.repo) == nil do
          {:ok, _pid} = tags.repo.start_link(tags.repo_config)
        end

        Sandbox.mode(tags.repo, :manual)
      end)
    else
      :ok = Sandbox.checkout(tags.repo)
    end

    :ok
  end

  test "durable preflight verifies the running repository and migrated schema", %{repo: repo} do
    assert :ok = Store.preflight(profile: :durable_redacted, repo: repo)
  end

  test "pre-start health uses a temporary Repo and leaves no process behind", %{
    repo_config: repo_config
  } do
    assert Process.whereis(TemporaryRepo) == nil

    assert :ok =
             Store.preflight(
               profile: :durable_redacted,
               repo: TemporaryRepo,
               repo_mode: :temporary,
               repo_options: repo_config
             )

    assert Process.whereis(TemporaryRepo) == nil
  end

  test "prompt context persists immutable payloads, lineage, and exact access scope", %{
    repo: repo
  } do
    prompt = prompt_context!("alpha")

    assert {:ok, ^prompt} = Store.record_prompt_context(prompt, tenant_id: @tenant_a, repo: repo)

    assert {:ok, fetched} =
             Store.fetch_semantic_context(@tenant_a, prompt.provenance.semantic_ref, repo: repo)

    assert fetched.provenance == prompt.provenance
    assert fetched.lineage.run_ref == prompt.run_ref
    assert fetched.lineage.turn_ref == prompt.turn_ref
    assert fetched.context_artifact_descriptor == prompt.context_artifact.descriptor
    assert fetched.prompt_artifact_descriptor == prompt.prompt_artifact.descriptor

    assert [indexed] =
             Store.search_semantic_contexts(@tenant_a, "gemini-2.5-flash alpha", repo: repo)

    assert indexed.provenance.semantic_ref == prompt.provenance.semantic_ref
    assert [] = Store.search_semantic_contexts(@tenant_b, "gemini-2.5-flash", repo: repo)

    assert {:ok, resolved} =
             Store.resolve_artifact_payload(
               prompt.prompt_artifact.descriptor.artifact_ref,
               artifact_access(@tenant_a, "alpha"),
               repo: repo
             )

    assert resolved.payload == prompt.prompt_artifact.payload
    assert resolved.descriptor == prompt.prompt_artifact.descriptor

    assert {:error, :artifact_access_denied} =
             Store.resolve_artifact_payload(
               prompt.prompt_artifact.descriptor.artifact_ref,
               %{artifact_access(@tenant_a, "alpha") | reader_ref: "reader://other"},
               repo: repo
             )

    assert {:error, :artifact_not_found} =
             Store.resolve_artifact_payload(
               prompt.prompt_artifact.descriptor.artifact_ref,
               artifact_access(@tenant_b, "alpha"),
               repo: repo
             )
  end

  test "exact prompt replay is idempotent and changed access scope conflicts", %{repo: repo} do
    prompt = prompt_context!("replay")

    assert {:ok, ^prompt} = Store.record_prompt_context(prompt, tenant_id: @tenant_a, repo: repo)
    assert {:ok, ^prompt} = Store.record_prompt_context(prompt, tenant_id: @tenant_a, repo: repo)

    changed_artifact = %{
      prompt.prompt_artifact
      | allowed_reader_refs: ["reader://other"]
    }

    conflicting = %{prompt | prompt_artifact: changed_artifact}

    assert {:error, {:artifact_payload_conflict, artifact_ref}} =
             Store.record_prompt_context(conflicting, tenant_id: @tenant_a, repo: repo)

    assert artifact_ref == prompt.prompt_artifact.descriptor.artifact_ref

    assert %{rows: [[2]]} =
             SQL.query!(
               repo,
               "SELECT count(*) FROM outer_brain_artifact_payloads WHERE authority_packet_ref = $1",
               ["authority-packet://gemini/replay"]
             )
  end

  test "artifact payload rows reject mutation", %{repo: repo} do
    prompt = prompt_context!("immutable")
    assert {:ok, ^prompt} = Store.record_prompt_context(prompt, tenant_id: @tenant_a, repo: repo)

    assert_raise Postgrex.Error, ~r/artifact payloads are immutable/, fn ->
      repo.query!(
        "UPDATE outer_brain_artifact_payloads SET payload = 'changed' WHERE artifact_ref = $1",
        [prompt.context_artifact.descriptor.artifact_ref]
      )
    end
  end

  test "semantic provenance rows reject mutation", %{repo: repo} do
    prompt = prompt_context!("semantic-immutable")
    assert {:ok, ^prompt} = Store.record_prompt_context(prompt, tenant_id: @tenant_a, repo: repo)

    assert_raise Postgrex.Error, ~r/semantic context provenance is immutable/, fn ->
      repo.query!(
        "UPDATE outer_brain_semantic_contexts SET provider_ref = 'provider://other' WHERE semantic_ref = $1",
        [prompt.provenance.semantic_ref]
      )
    end
  end

  @tag :repo_restart
  test "final reply, next context, and safe journal survive repository restart", %{
    repo: repo,
    repo_config: repo_config
  } do
    prompt = prompt_context!("restart")
    continuation = reply_continuation!(prompt, "restart")

    assert {:ok, ^prompt} = Store.record_prompt_context(prompt, tenant_id: @tenant_a, repo: repo)

    assert {:ok, persisted} =
             Store.publish_reply_continuation(continuation, tenant_id: @tenant_a, repo: repo)

    assert persisted.publication.run_ref == prompt.run_ref
    assert persisted.publication.turn_ref == prompt.turn_ref
    assert persisted.publication.attempt_ref == continuation.attempt_ref

    assert persisted.publication.reply_artifact_ref ==
             continuation.reply_artifact.descriptor.artifact_ref

    assert persisted.publication.next_semantic_ref == continuation.next_provenance.semantic_ref

    assert {:ok, ^persisted} =
             Store.publish_reply_continuation(continuation, tenant_id: @tenant_a, repo: repo)

    stop_repo_safely()
    {:ok, _pid} = Repo.start_link(repo_config)

    assert {:ok, next_context} =
             Store.fetch_semantic_context(
               @tenant_a,
               continuation.next_provenance.semantic_ref,
               repo: repo
             )

    assert next_context.lineage.previous_semantic_ref == prompt.provenance.semantic_ref

    assert latest = Store.latest_publication(@tenant_a, prompt.turn_ref, repo: repo)
    assert latest.attempt_ref == continuation.attempt_ref
    assert latest.next_semantic_ref == continuation.next_provenance.semantic_ref

    assert [journal_entry] = Store.journal_entries(@tenant_a, prompt.run_ref, repo: repo)
    assert journal_entry.entry_type == "assistant_reply_published"
    refute inspect(journal_entry.payload) =~ "Restart-safe assistant reply"

    assert {:ok, resolved_reply} =
             Store.resolve_artifact_payload(
               continuation.reply_artifact.descriptor.artifact_ref,
               artifact_access(@tenant_a, "restart"),
               repo: repo
             )

    assert resolved_reply.payload == "Restart-safe assistant reply"
  end

  test "secret-bearing assistant replies are rejected before persistence", %{repo: repo} do
    prompt = prompt_context!("secret-reply")
    assert {:ok, ^prompt} = Store.record_prompt_context(prompt, tenant_id: @tenant_a, repo: repo)

    assert {:error, :invalid_reply_continuation} =
             SemanticTurnArtifacts.prepare_reply(prompt, %{
               attempt_ref: "attempt://gemini/secret-reply",
               assistant_reply: "api_key=must-not-persist",
               dedupe_key: "secret-reply:final",
               published_at: ~U[2026-07-21 08:00:00Z],
               allowed_reader_refs: ["reader://synapse"],
               allowed_operation_refs: ["operation://synapse/read"]
             })

    assert [] = Store.reply_publications(@tenant_a, prompt.turn_ref, repo: repo)
  end

  test "lease acquisition persists fenced session ownership and expiry replacement", %{repo: repo} do
    now = DateTime.from_unix!(1_800_000_500)
    initial = lease!("session_alpha", "node_a", "lease_a", 1, DateTime.add(now, 1, :second))

    assert {:ok, :acquired, ^initial} =
             Store.acquire_lease(initial, now, tenant_id: @tenant_a, repo: repo)

    assert {:ok, fetched_initial} =
             Store.fetch_current_lease(@tenant_a, "session_alpha", repo: repo)

    assert fetched_initial.session_id == initial.session_id
    assert fetched_initial.holder == initial.holder
    assert fetched_initial.lease_id == initial.lease_id
    assert fetched_initial.epoch == initial.epoch
    assert DateTime.compare(fetched_initial.expires_at, initial.expires_at) == :eq

    later = DateTime.add(now, 5, :second)
    stale = lease!("session_alpha", "node_b", "lease_b", 1, DateTime.add(later, 30, :second))

    replacement =
      lease!("session_alpha", "node_b", "lease_b", 2, DateTime.add(later, 30, :second))

    assert {:error, {:stale_epoch, fence}} =
             Store.acquire_lease(stale, later, tenant_id: @tenant_a, repo: repo)

    assert fence.holder == "node_a"

    assert {:ok, :acquired, ^replacement} =
             Store.acquire_lease(replacement, later, tenant_id: @tenant_a, repo: repo)

    assert {:ok, fetched_replacement} =
             Store.fetch_current_lease(@tenant_a, "session_alpha", repo: repo)

    assert fetched_replacement.holder == replacement.holder
    assert fetched_replacement.lease_id == replacement.lease_id
    assert fetched_replacement.epoch == replacement.epoch
    assert DateTime.compare(fetched_replacement.expires_at, replacement.expires_at) == :eq
  end

  test "semantic journal entries append durably in recorded order", %{repo: repo} do
    first =
      journal_entry!(
        "entry_1",
        "session_alpha",
        "causal_1",
        "wake_input",
        DateTime.from_unix!(1_800_000_100),
        %{"turn_id" => "turn_1"}
      )

    second =
      journal_entry!(
        "entry_2",
        "session_alpha",
        "causal_1",
        "checkpoint",
        DateTime.from_unix!(1_800_000_110),
        %{"checkpoint" => "frame_compiled"}
      )

    assert {:ok, ^first} =
             Store.append_semantic_journal_entry(first, tenant_id: @tenant_a, repo: repo)

    assert {:ok, ^second} =
             Store.append_semantic_journal_entry(second, tenant_id: @tenant_a, repo: repo)

    assert [persisted_first, persisted_second] =
             Store.journal_entries(@tenant_a, "session_alpha", repo: repo)

    assert persisted_first.entry_id == first.entry_id
    assert persisted_first.entry_type == first.entry_type
    assert persisted_first.payload == first.payload
    assert persisted_first.persistence_posture.raw_provider_payload_persistence? == false
    assert DateTime.compare(persisted_first.recorded_at, first.recorded_at) == :eq
    assert persisted_second.entry_id == second.entry_id
    assert persisted_second.entry_type == second.entry_type
    assert persisted_second.payload == second.payload
    assert DateTime.compare(persisted_second.recorded_at, second.recorded_at) == :eq
  end

  test "raw and credential-shaped semantic journal payloads fail before insertion", %{repo: repo} do
    entry =
      journal_entry!(
        "entry_forbidden_payload",
        "session_alpha",
        "causal_1",
        "wake_input",
        DateTime.from_unix!(1_800_000_100),
        %{"nested" => %{"raw_provider_payload" => "must-not-persist"}}
      )

    assert {:error, {:forbidden_journal_payload_key, "raw_provider_payload"}} =
             Store.append_semantic_journal_entry(entry, tenant_id: @tenant_a, repo: repo)

    assert [] = Store.journal_entries(@tenant_a, "session_alpha", repo: repo)
  end

  test "restart-authority inputs preserve durable recovery tasks", %{repo: repo} do
    recovery_task =
      recovery_task!("recovery_1", "session_alpha", :ambiguous_submission, :pending)

    assert {:ok, ^recovery_task} =
             Store.record_recovery_task(recovery_task, tenant_id: @tenant_a, repo: repo)

    assert [^recovery_task] = Store.pending_recovery_tasks(@tenant_a, "session_alpha", repo: repo)
  end

  test "pending recovery tasks reject unknown persisted reasons", %{repo: repo} do
    repo.insert!(%RecoveryTaskSchema{
      task_id: "recovery_unknown_reason",
      tenant_id: @tenant_a,
      session_id: "session_alpha",
      reason: "not_a_recovery_reason",
      status: :pending
    })

    error =
      assert_raise ArgumentError, fn ->
        Store.pending_recovery_tasks(@tenant_a, "session_alpha", repo: repo)
      end

    assert String.contains?(Exception.message(error), "unknown recovery task reason")
  end

  test "tenant scope is part of every durable session query", %{repo: repo} do
    now = DateTime.from_unix!(1_800_000_500)

    tenant_a_lease =
      lease!("session_shared", "node_a", "lease_a", 1, DateTime.add(now, 30, :second))

    tenant_b_lease =
      lease!("session_shared", "node_b", "lease_b", 1, DateTime.add(now, 30, :second))

    assert {:ok, :acquired, ^tenant_a_lease} =
             Store.acquire_lease(tenant_a_lease, now, tenant_id: @tenant_a, repo: repo)

    assert {:ok, :acquired, ^tenant_b_lease} =
             Store.acquire_lease(tenant_b_lease, now, tenant_id: @tenant_b, repo: repo)

    assert {:ok, fetched_a} = Store.fetch_current_lease(@tenant_a, "session_shared", repo: repo)
    assert {:ok, fetched_b} = Store.fetch_current_lease(@tenant_b, "session_shared", repo: repo)
    assert fetched_a.holder == "node_a"
    assert fetched_b.holder == "node_b"

    journal_entry =
      journal_entry!("entry_shared", "session_shared", "causal_shared", "checkpoint", now, %{})

    recovery_task =
      recovery_task!("recovery_shared", "session_shared", :ambiguous_submission, :pending)

    assert {:ok, ^journal_entry} =
             Store.append_semantic_journal_entry(journal_entry, tenant_id: @tenant_a, repo: repo)

    assert {:ok, ^recovery_task} =
             Store.record_recovery_task(recovery_task, tenant_id: @tenant_a, repo: repo)

    assert [_] = Store.journal_entries(@tenant_a, "session_shared", repo: repo)
    assert [] = Store.journal_entries(@tenant_b, "session_shared", repo: repo)
    assert [_] = Store.pending_recovery_tasks(@tenant_a, "session_shared", repo: repo)
    assert [] = Store.pending_recovery_tasks(@tenant_b, "session_shared", repo: repo)
  end

  defp lease!(session_id, holder, lease_id, epoch, expires_at) do
    {:ok, lease} =
      Lease.new(%{
        session_id: session_id,
        holder: holder,
        lease_id: lease_id,
        epoch: epoch,
        expires_at: expires_at
      })

    lease
  end

  defp journal_entry!(entry_id, session_id, causal_unit_id, entry_type, recorded_at, payload) do
    {:ok, entry} =
      SemanticJournalEntryRecord.new(%{
        entry_id: entry_id,
        session_id: session_id,
        causal_unit_id: causal_unit_id,
        entry_type: entry_type,
        recorded_at: recorded_at,
        payload: payload
      })

    entry
  end

  defp recovery_task!(task_id, session_id, reason, status) do
    {:ok, task} =
      RecoveryTaskRecord.new(%{
        task_id: task_id,
        session_id: session_id,
        reason: reason,
        status: status
      })

    task
  end

  defp prompt_context!(suffix, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          tenant_ref: @tenant_a,
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
              artifact_ref: "artifact://synapse/#{suffix}/system",
              content_digest: "sha256:" <> String.duplicate("1", 64),
              role: "system_instruction"
            },
            %{
              artifact_ref: "artifact://synapse/#{suffix}/user",
              content_digest: "sha256:" <> String.duplicate("2", 64),
              role: "user_input"
            }
          ],
          memory_snapshot_refs: ["memory-snapshot://outer-brain/#{suffix}"],
          allowed_reader_refs: ["reader://synapse"],
          allowed_operation_refs: ["operation://synapse/read"]
        },
        Map.new(overrides)
      )

    {:ok, prompt} = SemanticTurnArtifacts.prepare_prompt(attrs)
    prompt
  end

  defp reply_continuation!(prompt, suffix, overrides \\ %{}) do
    attrs =
      Map.merge(
        %{
          attempt_ref: "attempt://jido/gemini/#{suffix}",
          assistant_reply: "Restart-safe assistant reply",
          dedupe_key: "#{prompt.turn_ref}:final",
          published_at: ~U[2026-07-21 08:00:00Z],
          allowed_reader_refs: ["reader://synapse"],
          allowed_operation_refs: ["operation://synapse/read"]
        },
        Map.new(overrides)
      )

    {:ok, continuation} = SemanticTurnArtifacts.prepare_reply(prompt, attrs)
    continuation
  end

  defp artifact_access(tenant_ref, suffix) do
    ArtifactAccess.new!(%{
      tenant_ref: tenant_ref,
      reader_ref: "reader://synapse",
      operation_ref: "operation://synapse/read",
      authority_packet_ref: "authority-packet://gemini/#{suffix}"
    })
  end

  defp stop_repo_safely do
    case Process.whereis(Repo) do
      pid when is_pid(pid) ->
        try do
          GenServer.stop(Repo)
        catch
          :exit, _reason -> :ok
        end

      nil ->
        :ok
    end
  end
end
