defmodule OuterBrain.Persistence.StoreTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias OuterBrain.Contracts.Lease
  alias OuterBrain.Contracts.ReplyBodyBoundary

  alias OuterBrain.Journal.Tables.{
    RecoveryTaskRecord,
    ReplyPublicationRecord,
    SemanticJournalEntryRecord
  }

  alias OuterBrain.Persistence.{PostgresContainer, Repo, Store}
  alias OuterBrain.Persistence.Schemas.RecoveryTask, as: RecoveryTaskSchema

  @moduletag :tenant_isolation
  @tenant_a "tenant://outer-brain/a"
  @tenant_b "tenant://outer-brain/b"

  test "memory preflight is non-mutating by default" do
    assert :ok = Store.preflight([])
    assert :ok = Store.preflight(profile: :mickey_mouse)
    assert :ok = Store.preflight(profile: :memory_debug)
  end

  test "postgres preflight fails before mutation when migration proof is missing" do
    assert {:error, {:missing_migration_proof, :outer_brain_persistence}} =
             Store.preflight(profile: :integration_postgres)
  end

  test "postgres preflight passes when migration proof is present" do
    assert :ok =
             Store.preflight(profile: :integration_postgres, migration_proof: :present)
  end

  setup_all do
    container = PostgresContainer.start!("outer_brain_persistence")

    {:ok, _pid} = Repo.start_link(PostgresContainer.repo_config(container.port))

    PostgresContainer.run_migrations!(Repo)
    Sandbox.mode(Repo, :manual)

    on_exit(fn ->
      stop_repo_safely()
      PostgresContainer.stop!(container)
    end)

    {:ok, repo: Repo}
  end

  setup %{repo: repo} do
    :ok = Sandbox.checkout(repo)
    :ok
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

  test "restart-authority inputs survive durable recovery task and publication writes", %{
    repo: repo
  } do
    recovery_task =
      recovery_task!("recovery_1", "session_alpha", :ambiguous_submission, :pending)

    provisional =
      reply_publication!(
        "publication_1",
        "causal_1",
        :provisional,
        :published,
        "causal_1:p",
        "Working"
      )

    final =
      reply_publication!("publication_2", "causal_1", :final, :published, "causal_1:f", "Done")

    assert {:ok, ^recovery_task} =
             Store.record_recovery_task(recovery_task, tenant_id: @tenant_a, repo: repo)

    assert {:ok, ^provisional} =
             Store.record_reply_publication(provisional, tenant_id: @tenant_a, repo: repo)

    assert {:ok, ^final} = Store.record_reply_publication(final, tenant_id: @tenant_a, repo: repo)

    assert [^recovery_task] = Store.pending_recovery_tasks(@tenant_a, "session_alpha", repo: repo)
    assert :final == Store.latest_publication_phase(@tenant_a, "causal_1", repo: repo)

    assert [persisted_provisional, persisted_final] =
             Store.reply_publications(@tenant_a, "causal_1", repo: repo)

    assert persisted_provisional.persistence_posture.raw_prompt_persistence? == false
    assert persisted_final.persistence_posture.raw_provider_payload_persistence? == false
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

  test "tenant scope is part of every durable session and publication query", %{repo: repo} do
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

    publication =
      reply_publication!(
        "publication_shared",
        "causal_shared",
        :final,
        :published,
        "shared:final",
        "Done"
      )

    assert {:ok, ^journal_entry} =
             Store.append_semantic_journal_entry(journal_entry, tenant_id: @tenant_a, repo: repo)

    assert {:ok, ^recovery_task} =
             Store.record_recovery_task(recovery_task, tenant_id: @tenant_a, repo: repo)

    assert {:ok, ^publication} =
             Store.record_reply_publication(publication, tenant_id: @tenant_a, repo: repo)

    assert [_] = Store.journal_entries(@tenant_a, "session_shared", repo: repo)
    assert [] = Store.journal_entries(@tenant_b, "session_shared", repo: repo)
    assert [_] = Store.pending_recovery_tasks(@tenant_a, "session_shared", repo: repo)
    assert [] = Store.pending_recovery_tasks(@tenant_b, "session_shared", repo: repo)
    assert [_] = Store.reply_publications(@tenant_a, "causal_shared", repo: repo)
    assert [] = Store.reply_publications(@tenant_b, "causal_shared", repo: repo)
    assert Store.latest_publication(@tenant_b, "causal_shared", repo: repo) == nil
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

  defp reply_publication!(publication_id, causal_unit_id, phase, state, dedupe_key, body) do
    {:ok, reply_body} = ReplyBodyBoundary.build(causal_unit_id, phase, dedupe_key, body)

    {:ok, publication} =
      ReplyPublicationRecord.new(%{
        publication_id: publication_id,
        causal_unit_id: causal_unit_id,
        phase: phase,
        state: state,
        dedupe_key: dedupe_key,
        body: reply_body.preview,
        body_ref: reply_body.ref
      })

    publication
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
