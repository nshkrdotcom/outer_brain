defmodule OuterBrain.Persistence.SemanticFailureRepository do
  @moduledoc false

  import Ecto.Query

  alias OuterBrain.Contracts.SemanticFailure
  alias OuterBrain.Persistence.Schemas.SemanticJournalEntry
  alias OuterBrain.Persistence.SemanticFailureMapper

  @semantic_failure_entry_type "semantic_failure"

  @spec record(module(), SemanticFailure.t(), DateTime.t()) ::
          {:ok, SemanticFailure.t()} | {:error, term()}
  def record(repo, %SemanticFailure{} = failure, %DateTime{} = recorded_at) do
    payload = SemanticFailure.to_payload(failure)

    changeset =
      SemanticJournalEntry.changeset(%SemanticJournalEntry{}, %{
        entry_id: SemanticFailure.journal_entry_id(failure),
        tenant_id: failure.tenant_id,
        session_id: failure.semantic_session_id,
        causal_unit_id: failure.causal_unit_id,
        entry_type: @semantic_failure_entry_type,
        payload: payload,
        recorded_at: recorded_at
      })

    case repo.insert(changeset,
           on_conflict: [set: [payload: payload, recorded_at: recorded_at]],
           conflict_target: :entry_id,
           returning: true
         ) do
      {:ok, schema} -> SemanticFailure.from_payload(schema.payload)
      {:error, changeset} -> {:error, changeset}
    end
  end

  @spec list(module(), String.t(), String.t()) :: [SemanticFailure.t()]
  def list(repo, tenant_id, session_id)
      when is_binary(tenant_id) and is_binary(session_id) do
    SemanticJournalEntry
    |> where(
      [entry],
      entry.tenant_id == ^tenant_id and entry.session_id == ^session_id and
        entry.entry_type == ^@semantic_failure_entry_type
    )
    |> order_by([entry], asc: entry.recorded_at, asc: entry.inserted_at)
    |> repo.all()
    |> Enum.map(&SemanticFailureMapper.from_schema!/1)
  end
end
