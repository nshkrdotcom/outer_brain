defmodule OuterBrain.Persistence.JournalRepository do
  @moduledoc false

  import Ecto.Query

  alias OuterBrain.Journal.Tables.SemanticJournalEntryRecord
  alias OuterBrain.Persistence.JournalMapper
  alias OuterBrain.Persistence.Schemas.SemanticJournalEntry

  @spec append(module(), String.t(), SemanticJournalEntryRecord.t()) ::
          {:ok, SemanticJournalEntryRecord.t()} | {:error, Ecto.Changeset.t()}
  def append(repo, tenant_id, %SemanticJournalEntryRecord{} = entry) do
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
