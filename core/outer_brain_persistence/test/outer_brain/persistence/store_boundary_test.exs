defmodule OuterBrain.Persistence.StoreBoundaryTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.ReplyBodyBoundary
  alias OuterBrain.Journal.Tables.ReplyPublicationRecord
  alias OuterBrain.Persistence.{Application, Bootstrap, DurableSupervisor, ProfilePolicy, Repo}
  alias OuterBrain.Persistence.ReplyPublicationMapper

  @tenant "tenant://outer-brain/boundary"

  defmodule ExplodingRepo do
    def query(_statement, _params), do: raise("postgres://user:secret@database.example/db")
  end

  test "production composition cannot select an empty or memory repository" do
    assert_raise ArgumentError, fn -> Application.children([]) end
    assert_raise ArgumentError, fn -> Application.children(profile: :mickey_mouse) end
    assert_raise ArgumentError, fn -> DurableSupervisor.start_link(profile: :off) end

    assert [
             {Repo, [pool_size: 1]},
             {Bootstrap, [profile: :durable_redacted, repo: Repo]}
           ] =
             Application.children(
               profile: :durable_redacted,
               repo_options: [pool_size: 1]
             )

    assert [{Bootstrap, [profile: :durable_redacted, repo: Repo]}] =
             Application.children(
               profile: :durable_redacted,
               repo_mode: :external
             )

    assert_raise ArgumentError, fn ->
      Application.children(profile: :durable_redacted, repo_mode: :disabled)
    end
  end

  test "profile policy requires the one durable production profile" do
    assert {:error, {:unsupported_persistence_tier, :outer_brain_persistence, _missing}} =
             ProfilePolicy.preflight(%{})

    assert {:error, {:unsupported_persistence_tier, :outer_brain_persistence, false}} =
             ProfilePolicy.preflight(%{profile: false})

    assert {:error, {:unsupported_persistence_tier, :outer_brain_persistence, :memory_debug}} =
             ProfilePolicy.preflight(%{profile: :memory_debug})

    assert {:error, {:repository_not_running, NotRunningRepo}} =
             ProfilePolicy.preflight(%{profile: :durable_redacted, repo: NotRunningRepo})
  end

  test "repository preflight errors never expose connection or credential material" do
    child_spec = %{
      id: ExplodingRepo,
      start: {Agent, :start_link, [fn -> nil end, [name: ExplodingRepo]]}
    }

    start_supervised!(child_spec)

    assert {:error, {:repository_preflight_failed, RuntimeError}} =
             ProfilePolicy.preflight(profile: :durable_redacted, repo: ExplodingRepo)
  end

  test "reply publication mapper owns schema attributes without mutating domain record" do
    publication = reply_publication!("publication_mapper", "causal_mapper", :final, "Mapped")

    lineage = %{
      run_ref: "run://mapper",
      turn_ref: "turn://mapper/1",
      attempt_ref: "attempt://mapper/1",
      reply_artifact_ref: "artifact://mapper/reply",
      next_semantic_ref: "semantic://mapper/next"
    }

    assert %{
             publication_id: "publication_mapper",
             tenant_id: @tenant,
             causal_unit_id: "causal_mapper",
             phase: :final,
             state: :published,
             dedupe_key: "causal_mapper:final",
             body: "Mapped",
             body_ref: body_ref,
             run_ref: "run://mapper",
             turn_ref: "turn://mapper/1",
             attempt_ref: "attempt://mapper/1",
             reply_artifact_ref: "artifact://mapper/reply",
             next_semantic_ref: "semantic://mapper/next"
           } = ReplyPublicationMapper.to_schema_attrs(@tenant, publication, lineage)

    assert body_ref == publication.body_ref
    assert publication.body == "Mapped"
  end

  defp reply_publication!(publication_id, causal_unit_id, phase, body) do
    dedupe_key = causal_unit_id <> ":" <> Atom.to_string(phase)
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
end
