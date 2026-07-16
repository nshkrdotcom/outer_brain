defmodule OuterBrain.Persistence.Repo.Migrations.CreateSemanticContextAndArtifactIndex do
  use Ecto.Migration

  def up do
    create table(:outer_brain_artifact_descriptors, primary_key: false) do
      add(:artifact_ref, :string, primary_key: true)
      add(:tenant_ref, :string, null: false)
      add(:owner_ref, :string, null: false)
      add(:content_digest, :string, null: false)
      add(:size_bytes, :bigint, null: false)
      add(:media_type, :string, null: false)
      add(:schema_ref, :string, null: false)
      add(:schema_version, :bigint, null: false)
      add(:classification, :string, null: false)
      add(:provenance, :map, null: false)
      add(:causal_parent_refs, {:array, :string}, null: false, default: [])
      add(:producing_operation_ref, :string, null: false)
      add(:retention, :map, null: false)
      add(:deletion_state, :string, null: false)
      add(:location_ref, :string)
      add(:descriptor_digest, :string, null: false)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(unique_index(:outer_brain_artifact_descriptors, [:tenant_ref, :artifact_ref]))
    create(index(:outer_brain_artifact_descriptors, [:tenant_ref, :content_digest]))

    create(
      constraint(:outer_brain_artifact_descriptors, :artifact_size_non_negative,
        check: "size_bytes >= 0"
      )
    )

    create(
      constraint(:outer_brain_artifact_descriptors, :artifact_schema_version_positive,
        check: "schema_version > 0"
      )
    )

    create(
      constraint(:outer_brain_artifact_descriptors, :artifact_classification_valid,
        check: "classification IN ('public', 'internal', 'confidential', 'restricted')"
      )
    )

    create(
      constraint(:outer_brain_artifact_descriptors, :artifact_deletion_state_valid,
        check: "deletion_state IN ('active', 'tombstoned', 'deleted')"
      )
    )

    execute("""
    CREATE FUNCTION outer_brain_reject_artifact_mutation()
    RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION 'outer_brain artifact descriptors are immutable';
    END;
    $$ LANGUAGE plpgsql
    """)

    execute("""
    CREATE TRIGGER outer_brain_artifact_descriptors_immutable
    BEFORE UPDATE OR DELETE ON outer_brain_artifact_descriptors
    FOR EACH ROW EXECUTE FUNCTION outer_brain_reject_artifact_mutation()
    """)

    create table(:outer_brain_semantic_contexts, primary_key: false) do
      add(:semantic_ref, :string, primary_key: true)
      add(:tenant_ref, :string, null: false)
      add(:installation_ref, :string, null: false)
      add(:workspace_ref, :string, null: false)
      add(:project_ref, :string, null: false)
      add(:environment_ref, :string, null: false)
      add(:resource_ref, :string, null: false)
      add(:authority_packet_ref, :string, null: false)
      add(:permission_decision_ref, :string, null: false)
      add(:idempotency_key, :string, null: false)
      add(:trace_id, :string, null: false)
      add(:correlation_id, :string, null: false)
      add(:release_manifest_ref, :string, null: false)
      add(:principal_ref, :string)
      add(:system_actor_ref, :string)
      add(:provider_ref, :string, null: false)
      add(:model_ref, :string, null: false)
      add(:prompt_hash, :string, null: false)
      add(:context_hash, :string, null: false)
      add(:input_claim_check_ref, :string, null: false)
      add(:output_claim_check_ref, :string, null: false)
      add(:provenance_refs, {:array, :string}, null: false)
      add(:normalizer_version, :string, null: false)
      add(:redaction_policy_ref, :string, null: false)
      add(:artifact_ref, :string, null: false)
      add(:provenance_digest, :string, null: false)
      add(:search_document, :text, null: false)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(unique_index(:outer_brain_semantic_contexts, [:tenant_ref, :semantic_ref]))
    create(unique_index(:outer_brain_semantic_contexts, [:tenant_ref, :idempotency_key]))

    create(
      index(:outer_brain_semantic_contexts, [
        :tenant_ref,
        :workspace_ref,
        :project_ref,
        :environment_ref,
        :resource_ref
      ])
    )

    execute("""
    CREATE INDEX outer_brain_semantic_contexts_reference_search_idx
    ON outer_brain_semantic_contexts USING gin (
      to_tsvector(
        'simple',
        search_document
      )
    )
    """)

    execute("""
    CREATE FUNCTION outer_brain_reject_semantic_context_mutation()
    RETURNS trigger AS $$
    BEGIN
      RAISE EXCEPTION 'outer_brain semantic context provenance is immutable';
    END;
    $$ LANGUAGE plpgsql
    """)

    execute("""
    CREATE TRIGGER outer_brain_semantic_contexts_immutable
    BEFORE UPDATE OR DELETE ON outer_brain_semantic_contexts
    FOR EACH ROW EXECUTE FUNCTION outer_brain_reject_semantic_context_mutation()
    """)
  end

  def down do
    drop(table(:outer_brain_semantic_contexts))
    execute("DROP FUNCTION outer_brain_reject_semantic_context_mutation()")
    drop(table(:outer_brain_artifact_descriptors))
    execute("DROP FUNCTION outer_brain_reject_artifact_mutation()")
  end
end
