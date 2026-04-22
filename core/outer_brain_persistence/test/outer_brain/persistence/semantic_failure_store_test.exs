defmodule OuterBrain.Persistence.SemanticFailureStoreTest do
  use ExUnit.Case, async: false

  alias Ecto.Adapters.SQL.Sandbox
  alias OuterBrain.Contracts.ReplyBodyBoundary
  alias OuterBrain.Contracts.SemanticFailure
  alias OuterBrain.Journal.Tables.ReplyPublicationRecord
  alias OuterBrain.Persistence.{PostgresContainer, Repo, Store}

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

    replayed =
      semantic_failure!(
        operator_message: "The semantic host still needs a workspace clarification."
      )

    assert {:ok, ^failure} = Store.record_semantic_failure(failure, repo: repo)
    assert {:ok, persisted_replay} = Store.record_semantic_failure(replayed, repo: repo)
    assert persisted_replay.operator_message == replayed.operator_message

    assert [persisted] = Store.semantic_failure_entries("session-semantic-1", repo: repo)
    assert persisted.kind == :semantic_insufficient_context
    assert persisted.operator_message == replayed.operator_message
    assert persisted.provenance == [%{"source" => "semantic-host"}]
  end

  test "reply publications are idempotent by dedupe key across restart replay", %{repo: repo} do
    first =
      reply_publication!(
        "publication-original",
        "causal-publication-1",
        :final,
        "causal-publication-1:final",
        "Done"
      )

    same_replay =
      reply_publication!(
        "publication-replayed",
        "causal-publication-1",
        :final,
        "causal-publication-1:final",
        "Done"
      )

    mismatched_replay =
      reply_publication!(
        "publication-replayed-mismatch",
        "causal-publication-1",
        :final,
        "causal-publication-1:final",
        "Done after replay"
      )

    assert {:ok, persisted_first} = Store.record_reply_publication(first, repo: repo)
    assert persisted_first.publication_id == "publication-original"

    assert {:ok, persisted_replay} = Store.record_reply_publication(same_replay, repo: repo)
    assert persisted_replay.publication_id == "publication-original"
    assert persisted_replay.body_ref["body_hash"] == first.body_ref["body_hash"]

    assert {:error, {:reply_publication_body_ref_mismatch, mismatch}} =
             Store.record_reply_publication(mismatched_replay, repo: repo)

    assert mismatch.dedupe_key == "causal-publication-1:final"
    assert mismatch.existing_body_hash == first.body_ref["body_hash"]
    assert mismatch.replay_body_hash == mismatched_replay.body_ref["body_hash"]

    assert [publication] = Store.reply_publications("causal-publication-1", repo: repo)
    assert publication.publication_id == "publication-original"
    assert publication.dedupe_key == "causal-publication-1:final"
    assert publication.body_ref["body_hash"] == first.body_ref["body_hash"]
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

  defp reply_publication!(publication_id, causal_unit_id, phase, dedupe_key, body) do
    {:ok, reply_body} = ReplyBodyBoundary.build(causal_unit_id, phase, dedupe_key, body)

    {:ok, publication} =
      ReplyPublicationRecord.new(%{
        publication_id: publication_id,
        causal_unit_id: causal_unit_id,
        phase: phase,
        state: :published,
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
