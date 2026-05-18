defmodule OuterBrain.Persistence.Repo.Migrations.ScopeStageOneDurabilityByTenant do
  use Ecto.Migration

  def change do
    alter table(:semantic_session_leases) do
      add(:tenant_id, :string, null: false, default: "tenant://legacy-unscoped")
    end

    execute(
      "ALTER TABLE semantic_session_leases ALTER COLUMN tenant_id DROP DEFAULT",
      "ALTER TABLE semantic_session_leases ALTER COLUMN tenant_id SET DEFAULT 'tenant://legacy-unscoped'"
    )

    drop_if_exists(unique_index(:semantic_session_leases, [:session_id]))
    create(unique_index(:semantic_session_leases, [:tenant_id, :session_id]))

    alter table(:semantic_journal_entries) do
      add(:tenant_id, :string, null: false, default: "tenant://legacy-unscoped")
    end

    execute(
      "ALTER TABLE semantic_journal_entries ALTER COLUMN tenant_id DROP DEFAULT",
      "ALTER TABLE semantic_journal_entries ALTER COLUMN tenant_id SET DEFAULT 'tenant://legacy-unscoped'"
    )

    create(index(:semantic_journal_entries, [:tenant_id, :session_id, :recorded_at]))
    create(index(:semantic_journal_entries, [:tenant_id, :causal_unit_id, :recorded_at]))

    alter table(:recovery_tasks) do
      add(:tenant_id, :string, null: false, default: "tenant://legacy-unscoped")
    end

    execute(
      "ALTER TABLE recovery_tasks ALTER COLUMN tenant_id DROP DEFAULT",
      "ALTER TABLE recovery_tasks ALTER COLUMN tenant_id SET DEFAULT 'tenant://legacy-unscoped'"
    )

    create(index(:recovery_tasks, [:tenant_id, :session_id, :status]))

    alter table(:reply_publications) do
      add(:tenant_id, :string, null: false, default: "tenant://legacy-unscoped")
    end

    execute(
      "ALTER TABLE reply_publications ALTER COLUMN tenant_id DROP DEFAULT",
      "ALTER TABLE reply_publications ALTER COLUMN tenant_id SET DEFAULT 'tenant://legacy-unscoped'"
    )

    drop_if_exists(unique_index(:reply_publications, [:dedupe_key]))
    create(unique_index(:reply_publications, [:tenant_id, :dedupe_key]))
    create(index(:reply_publications, [:tenant_id, :causal_unit_id, :phase]))
  end
end
