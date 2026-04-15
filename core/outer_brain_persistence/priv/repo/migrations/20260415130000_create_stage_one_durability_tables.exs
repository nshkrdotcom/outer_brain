defmodule OuterBrain.Persistence.Repo.Migrations.CreateStageOneDurabilityTables do
  use Ecto.Migration

  def change do
    create table(:semantic_session_leases, primary_key: false) do
      add(:row_id, :string, primary_key: true)
      add(:session_id, :string, null: false)
      add(:holder, :string, null: false)
      add(:lease_id, :string, null: false)
      add(:epoch, :bigint, null: false)
      add(:expires_at, :utc_datetime_usec, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:semantic_session_leases, [:session_id]))

    create table(:semantic_journal_entries, primary_key: false) do
      add(:entry_id, :string, primary_key: true)
      add(:session_id, :string, null: false)
      add(:causal_unit_id, :string, null: false)
      add(:entry_type, :string, null: false)
      add(:payload, :map, null: false, default: %{})
      add(:recorded_at, :utc_datetime_usec, null: false)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create(index(:semantic_journal_entries, [:session_id, :recorded_at]))
    create(index(:semantic_journal_entries, [:causal_unit_id, :recorded_at]))

    create table(:recovery_tasks, primary_key: false) do
      add(:task_id, :string, primary_key: true)
      add(:session_id, :string, null: false)
      add(:reason, :string, null: false)
      add(:status, :string, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(index(:recovery_tasks, [:session_id, :status]))

    create table(:reply_publications, primary_key: false) do
      add(:publication_id, :string, primary_key: true)
      add(:causal_unit_id, :string, null: false)
      add(:phase, :string, null: false)
      add(:state, :string, null: false)
      add(:dedupe_key, :string, null: false)
      add(:body, :text, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:reply_publications, [:dedupe_key]))
    create(index(:reply_publications, [:causal_unit_id, :phase]))
  end
end
