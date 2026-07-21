defmodule OuterBrain.Persistence.Repo.Migrations.AddImmutableSemanticTurnArtifacts do
  use Ecto.Migration

  def up do
    create table(:outer_brain_artifact_payloads, primary_key: false) do
      add(
        :artifact_ref,
        references(:outer_brain_artifact_descriptors,
          column: :artifact_ref,
          type: :string,
          on_delete: :restrict
        ),
        primary_key: true
      )

      add(:tenant_ref, :string, null: false)
      add(:content_digest, :string, null: false)
      add(:media_type, :string, null: false)
      add(:payload, :binary, null: false)
      add(:authority_packet_ref, :string, null: false)
      add(:allowed_reader_refs, {:array, :string}, null: false)
      add(:allowed_operation_refs, {:array, :string}, null: false)
      add(:record_digest, :string, null: false)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(unique_index(:outer_brain_artifact_payloads, [:tenant_ref, :artifact_ref]))

    execute("""
    CREATE FUNCTION outer_brain_reject_artifact_payload_mutation()
    RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION 'outer_brain artifact payloads are immutable';
    END;
    $$ LANGUAGE plpgsql
    """)

    execute("""
    CREATE TRIGGER outer_brain_artifact_payloads_immutable
    BEFORE UPDATE OR DELETE ON outer_brain_artifact_payloads
    FOR EACH ROW EXECUTE FUNCTION outer_brain_reject_artifact_payload_mutation()
    """)

    execute(
      "DROP TRIGGER outer_brain_semantic_contexts_immutable ON outer_brain_semantic_contexts"
    )

    alter table(:outer_brain_semantic_contexts) do
      add(:run_ref, :string)
      add(:turn_ref, :string)
      add(:context_artifact_ref, :string)
      add(:prompt_artifact_ref, :string)
      add(:model_profile_ref, :string)
      add(:memory_snapshot_refs, {:array, :string}, null: false, default: [])
      add(:previous_semantic_ref, :string)
    end

    execute("""
    UPDATE outer_brain_semantic_contexts
    SET run_ref = resource_ref,
        turn_ref = resource_ref,
        context_artifact_ref = artifact_ref,
        prompt_artifact_ref = artifact_ref,
        model_profile_ref = model_ref
    """)

    execute("ALTER TABLE outer_brain_semantic_contexts ALTER COLUMN run_ref SET NOT NULL")
    execute("ALTER TABLE outer_brain_semantic_contexts ALTER COLUMN turn_ref SET NOT NULL")

    execute(
      "ALTER TABLE outer_brain_semantic_contexts ALTER COLUMN context_artifact_ref SET NOT NULL"
    )

    execute(
      "ALTER TABLE outer_brain_semantic_contexts ALTER COLUMN prompt_artifact_ref SET NOT NULL"
    )

    execute(
      "ALTER TABLE outer_brain_semantic_contexts ALTER COLUMN model_profile_ref SET NOT NULL"
    )

    alter table(:outer_brain_semantic_contexts) do
      remove(:artifact_ref)
    end

    create(index(:outer_brain_semantic_contexts, [:tenant_ref, :run_ref, :turn_ref]))

    execute("""
    CREATE TRIGGER outer_brain_semantic_contexts_immutable
    BEFORE UPDATE OR DELETE ON outer_brain_semantic_contexts
    FOR EACH ROW EXECUTE FUNCTION outer_brain_reject_semantic_context_mutation()
    """)

    alter table(:reply_publications) do
      add(:run_ref, :string)
      add(:turn_ref, :string)
      add(:attempt_ref, :string)
      add(:reply_artifact_ref, :string)
      add(:next_semantic_ref, :string)
    end

    execute("""
    UPDATE reply_publications
    SET run_ref = causal_unit_id,
        turn_ref = causal_unit_id,
        attempt_ref = 'attempt-ref://legacy/' || publication_id,
        reply_artifact_ref = COALESCE(body_ref->>'artifact_id', 'artifact-ref://legacy/' || publication_id),
        next_semantic_ref = 'semantic-ref://legacy/' || publication_id
    """)

    execute("ALTER TABLE reply_publications ALTER COLUMN run_ref SET NOT NULL")
    execute("ALTER TABLE reply_publications ALTER COLUMN turn_ref SET NOT NULL")
    execute("ALTER TABLE reply_publications ALTER COLUMN attempt_ref SET NOT NULL")
    execute("ALTER TABLE reply_publications ALTER COLUMN reply_artifact_ref SET NOT NULL")
    execute("ALTER TABLE reply_publications ALTER COLUMN next_semantic_ref SET NOT NULL")

    execute("""
    CREATE FUNCTION outer_brain_reject_reply_publication_mutation()
    RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION 'outer_brain reply publications are immutable';
    END;
    $$ LANGUAGE plpgsql
    """)

    execute("""
    CREATE TRIGGER outer_brain_reply_publications_immutable
    BEFORE UPDATE OR DELETE ON reply_publications
    FOR EACH ROW EXECUTE FUNCTION outer_brain_reject_reply_publication_mutation()
    """)
  end

  def down do
    execute("DROP TRIGGER outer_brain_reply_publications_immutable ON reply_publications")
    execute("DROP FUNCTION outer_brain_reject_reply_publication_mutation()")

    alter table(:reply_publications) do
      remove(:run_ref)
      remove(:turn_ref)
      remove(:attempt_ref)
      remove(:reply_artifact_ref)
      remove(:next_semantic_ref)
    end

    execute(
      "DROP TRIGGER outer_brain_semantic_contexts_immutable ON outer_brain_semantic_contexts"
    )

    alter table(:outer_brain_semantic_contexts) do
      add(:artifact_ref, :string)
    end

    execute("UPDATE outer_brain_semantic_contexts SET artifact_ref = context_artifact_ref")
    execute("ALTER TABLE outer_brain_semantic_contexts ALTER COLUMN artifact_ref SET NOT NULL")

    alter table(:outer_brain_semantic_contexts) do
      remove(:run_ref)
      remove(:turn_ref)
      remove(:context_artifact_ref)
      remove(:prompt_artifact_ref)
      remove(:model_profile_ref)
      remove(:memory_snapshot_refs)
      remove(:previous_semantic_ref)
    end

    execute("""
    CREATE TRIGGER outer_brain_semantic_contexts_immutable
    BEFORE UPDATE OR DELETE ON outer_brain_semantic_contexts
    FOR EACH ROW EXECUTE FUNCTION outer_brain_reject_semantic_context_mutation()
    """)

    execute(
      "DROP TRIGGER outer_brain_artifact_payloads_immutable ON outer_brain_artifact_payloads"
    )

    execute("DROP FUNCTION outer_brain_reject_artifact_payload_mutation()")
    drop(table(:outer_brain_artifact_payloads))
  end
end
