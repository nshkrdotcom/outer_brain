defmodule OuterBrain.Persistence.SemanticFailureStoreTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias OuterBrain.Contracts.SemanticFailure
  alias OuterBrain.Persistence.{PostgresContainer, Repo, Store}

  @moduletag :tenant_isolation
  @tenant "tenant-semantic"

  setup_all do
    container = PostgresContainer.start!("outer_brain_semantic_failure_store")

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

  test "semantic failures are recorded durably as idempotent journal entries", %{repo: repo} do
    failure =
      semantic_failure!(operator_message: "The semantic host needs a workspace clarification.")

    same_replay =
      semantic_failure!(operator_message: "The semantic host needs a workspace clarification.")

    changed_failure =
      semantic_failure!(
        operator_message: "The semantic host still needs a workspace clarification."
      )

    assert {:ok, ^failure} =
             Store.record_semantic_failure(failure,
               repo: repo,
               recorded_at: ~U[2026-04-21 10:00:00Z]
             )

    assert {:ok, persisted_replay} =
             Store.record_semantic_failure(same_replay,
               repo: repo,
               recorded_at: ~U[2026-04-21 10:01:00Z]
             )

    assert persisted_replay.operator_message == same_replay.operator_message

    assert [persisted] = Store.semantic_failure_entries(@tenant, "session-semantic-1", repo: repo)
    assert persisted.kind == :semantic_insufficient_context
    assert persisted.operator_message == same_replay.operator_message
    assert persisted.provenance == [%{"source" => "semantic-host"}]

    assert [journal_entry] = Store.journal_entries(@tenant, "session-semantic-1", repo: repo)
    assert journal_entry.entry_id == SemanticFailure.journal_entry_id(failure)
    assert String.starts_with?(journal_entry.entry_id, "semantic_failure_journal:v1:")
    refute String.starts_with?(journal_entry.entry_id, "semantic_failure:")

    assert {:ok, ^changed_failure} =
             Store.record_semantic_failure(changed_failure,
               repo: repo,
               recorded_at: ~U[2026-04-21 10:02:00Z]
             )

    assert [first, second] =
             Store.semantic_failure_entries(@tenant, "session-semantic-1", repo: repo)

    assert first.operator_message == "The semantic host needs a workspace clarification."
    assert second.operator_message == "The semantic host still needs a workspace clarification."

    journal_entry_ids =
      Store.journal_entries(@tenant, "session-semantic-1", repo: repo)
      |> Enum.map(& &1.entry_id)

    assert journal_entry_ids == [
             SemanticFailure.journal_entry_id(failure),
             SemanticFailure.journal_entry_id(changed_failure)
           ]

    assert Enum.all?(journal_entry_ids, &String.starts_with?(&1, "semantic_failure_journal:v1:"))
    refute Enum.any?(journal_entry_ids, &String.starts_with?(&1, "semantic_failure:"))
  end

  test "structured semantic failure ids avoid delimiter collisions from legacy ids", %{repo: repo} do
    left =
      semantic_failure!(
        semantic_session_id: "session:semantic",
        causal_unit_id: "turn",
        operator_message: "Left side of delimiter collision."
      )

    right =
      semantic_failure!(
        semantic_session_id: "session",
        causal_unit_id: "semantic:turn",
        operator_message: "Right side of delimiter collision."
      )

    assert SemanticFailure.legacy_journal_entry_id(left) ==
             SemanticFailure.legacy_journal_entry_id(right)

    assert {:error, :legacy_semantic_failure_journal_id_ambiguous} =
             left
             |> SemanticFailure.legacy_journal_entry_id()
             |> SemanticFailure.parse_legacy_journal_entry_id()

    assert SemanticFailure.journal_entry_id(left) != SemanticFailure.journal_entry_id(right)

    assert {:ok, ^left} = Store.record_semantic_failure(left, repo: repo)
    assert {:ok, ^right} = Store.record_semantic_failure(right, repo: repo)

    assert [left_entry] = Store.journal_entries(@tenant, "session:semantic", repo: repo)
    assert [right_entry] = Store.journal_entries(@tenant, "session", repo: repo)

    assert left_entry.entry_id == SemanticFailure.journal_entry_id(left)
    assert right_entry.entry_id == SemanticFailure.journal_entry_id(right)
    assert String.starts_with?(left_entry.entry_id, "semantic_failure_journal:v1:")
    assert String.starts_with?(right_entry.entry_id, "semantic_failure_journal:v1:")
  end

  test "semantic failure provenance cannot bypass journal redaction", %{repo: repo} do
    failure =
      semantic_failure!(provenance: [%{"nested" => %{"access_token" => "must-not-persist"}}])

    assert {:error, {:forbidden_journal_payload_key, "access_token"}} =
             Store.record_semantic_failure(failure, repo: repo)

    assert [] = Store.semantic_failure_entries(@tenant, "session-semantic-1", repo: repo)
  end

  test "semantic failure readback cannot cross tenants", %{repo: repo} do
    failure = semantic_failure!(operator_message: "Tenant-owned semantic failure.")

    assert {:ok, ^failure} = Store.record_semantic_failure(failure, repo: repo)

    assert [_] = Store.semantic_failure_entries(@tenant, "session-semantic-1", repo: repo)
    assert [] = Store.semantic_failure_entries("tenant-other", "session-semantic-1", repo: repo)
  end

  defp semantic_failure!(overrides) do
    attrs =
      Map.merge(
        %{
          kind: :semantic_insufficient_context,
          tenant_id: "tenant-semantic",
          semantic_session_id: "session-semantic-1",
          causal_unit_id: "turn-semantic-1",
          request_trace_id: "trace-semantic-1",
          provenance: [%{"source" => "semantic-host"}],
          operator_message: "The semantic host needs clarification."
        },
        Map.new(overrides)
      )

    {:ok, failure} = SemanticFailure.new(attrs)
    failure
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
