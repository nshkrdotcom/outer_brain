defmodule OuterBrain.Persistence.JournalRepository do
  @moduledoc false

  import Ecto.Query

  alias OuterBrain.Journal.Tables.SemanticJournalEntryRecord
  alias OuterBrain.Persistence.{JournalMapper, JournalPayloadPolicy}
  alias OuterBrain.Persistence.Schemas.SemanticJournalEntry

  @spec append(module(), String.t(), SemanticJournalEntryRecord.t()) ::
          {:ok, SemanticJournalEntryRecord.t()} | {:error, Ecto.Changeset.t() | term()}
  def append(repo, tenant_id, %SemanticJournalEntryRecord{} = entry) do
    with :ok <- JournalPayloadPolicy.validate(entry.payload) do
      existing =
        SemanticJournalEntry
        |> where([row], row.tenant_id == ^tenant_id and row.entry_id == ^entry.entry_id)
        |> lock("FOR UPDATE")
        |> repo.one()

      case existing do
        nil -> insert(repo, tenant_id, entry)
        schema -> verify_idempotent(schema, entry)
      end
    end
  end

  defp insert(repo, tenant_id, entry) do
    %SemanticJournalEntry{}
    |> SemanticJournalEntry.changeset(%{
      entry_id: entry.entry_id,
      tenant_id: tenant_id,
      session_id: entry.session_id,
      causal_unit_id: entry.causal_unit_id,
      entry_type: entry.entry_type,
      payload: entry.payload,
      recorded_at: entry.recorded_at
    })
    |> repo.insert()
    |> case do
      {:ok, _schema} -> {:ok, entry}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp verify_idempotent(schema, entry) do
    persisted = JournalMapper.from_schema(schema)

    if exact_entry?(persisted, entry),
      do: {:ok, persisted},
      else: {:error, {:semantic_journal_conflict, entry.entry_id}}
  end

  defp exact_entry?(persisted, entry) do
    persisted.entry_id == entry.entry_id and
      persisted.session_id == entry.session_id and
      persisted.causal_unit_id == entry.causal_unit_id and
      persisted.entry_type == entry.entry_type and
      persisted.payload == entry.payload and
      DateTime.compare(persisted.recorded_at, entry.recorded_at) == :eq and
      persisted.persistence_posture == entry.persistence_posture
  end

  @spec list(module(), String.t(), String.t()) :: [SemanticJournalEntryRecord.t()]
  def list(repo, tenant_id, session_id)
      when is_binary(tenant_id) and is_binary(session_id) do
    SemanticJournalEntry
    |> where([entry], entry.tenant_id == ^tenant_id and entry.session_id == ^session_id)
    |> order_by([entry], asc: entry.recorded_at, asc: entry.inserted_at)
    |> repo.all()
    |> Enum.map(&JournalMapper.from_schema/1)
  end
end
