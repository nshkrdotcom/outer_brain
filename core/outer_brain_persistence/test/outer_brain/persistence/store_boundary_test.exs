defmodule OuterBrain.Persistence.StoreBoundaryTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.ReplyBodyBoundary
  alias OuterBrain.Journal.Tables.ReplyPublicationRecord
  alias OuterBrain.Persistence.Application, as: PersistenceApplication
  alias OuterBrain.Persistence.ProfilePolicy
  alias OuterBrain.Persistence.ReplyPublicationMapper

  @tenant "tenant://outer-brain/boundary"

  test "application supervision is selected by explicit boot args" do
    assert [] = PersistenceApplication.children([])
    assert [] = PersistenceApplication.children(enabled: false)
    assert [OuterBrain.Persistence.Repo] = PersistenceApplication.children(enabled: true)

    repo_child = {OuterBrain.Persistence.Repo, pool_size: 1}
    assert [^repo_child] = PersistenceApplication.children(enabled: true, repo_child: repo_child)
  end

  test "profile policy treats false and nil options explicitly" do
    assert {:error, {:missing_migration_proof, :outer_brain_persistence}} =
             ProfilePolicy.preflight(%{
               :profile => :integration_postgres,
               :migration_proof => false,
               "migration_proof" => :present
             })

    assert {:error, {:missing_migration_proof, :outer_brain_persistence}} =
             ProfilePolicy.preflight(%{profile: :integration_postgres, migration_proof: nil})

    assert {:error, {:unsupported_persistence_tier, :outer_brain_persistence, false}} =
             ProfilePolicy.preflight(%{profile: false})
  end

  test "reply publication mapper owns schema attributes without mutating domain record" do
    publication = reply_publication!("publication_mapper", "causal_mapper", :final, "Mapped")

    assert %{
             publication_id: "publication_mapper",
             tenant_id: @tenant,
             causal_unit_id: "causal_mapper",
             phase: :final,
             state: :published,
             dedupe_key: "causal_mapper:final",
             body: "Mapped",
             body_ref: body_ref
           } = ReplyPublicationMapper.to_schema_attrs(@tenant, publication)

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
