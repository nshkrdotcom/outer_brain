defmodule OuterBrain.Persistence.ReplyPublicationRepository do
  @moduledoc false

  import Ecto.Query

  alias OuterBrain.Contracts.ReplyBodyBoundary
  alias OuterBrain.Journal.Tables.ReplyPublicationRecord
  alias OuterBrain.Persistence.ReplyPublicationMapper
  alias OuterBrain.Persistence.Schemas.ReplyPublication

  @spec record(module(), String.t(), ReplyPublicationRecord.t(), map()) ::
          {:ok, ReplyPublicationRecord.t()} | {:error, Ecto.Changeset.t() | term()}
  def record(repo, tenant_id, %ReplyPublicationRecord{} = publication, lineage) do
    case repo.transaction(fn -> record_in_transaction(repo, tenant_id, publication, lineage) end) do
      {:ok, publication} -> {:ok, publication}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec record_in_transaction(module(), String.t(), ReplyPublicationRecord.t(), map()) ::
          ReplyPublicationRecord.t()
  def record_in_transaction(repo, tenant_id, %ReplyPublicationRecord{} = publication, lineage) do
    do_record(repo, tenant_id, publication, lineage)
  end

  @spec list(module(), String.t(), String.t()) :: [ReplyPublicationRecord.t()]
  def list(repo, tenant_id, causal_unit_id)
      when is_binary(tenant_id) and is_binary(causal_unit_id) do
    ReplyPublication
    |> where(
      [publication],
      publication.tenant_id == ^tenant_id and publication.causal_unit_id == ^causal_unit_id
    )
    |> order_by([publication], asc: publication.inserted_at, asc: publication.publication_id)
    |> repo.all()
    |> Enum.map(&ReplyPublicationMapper.from_schema/1)
  end

  @spec latest(module(), String.t(), String.t()) :: ReplyPublicationRecord.t() | nil
  def latest(repo, tenant_id, causal_unit_id)
      when is_binary(tenant_id) and is_binary(causal_unit_id) do
    repo
    |> latest_query(tenant_id, causal_unit_id)
    |> case do
      nil -> nil
      schema -> ReplyPublicationMapper.from_schema(schema)
    end
  end

  @spec latest_phase(module(), String.t(), String.t()) :: :final | :provisional | nil
  def latest_phase(repo, tenant_id, causal_unit_id)
      when is_binary(tenant_id) and is_binary(causal_unit_id) do
    ReplyPublication
    |> where(
      [publication],
      publication.tenant_id == ^tenant_id and publication.causal_unit_id == ^causal_unit_id
    )
    |> order_by_latest_phase()
    |> select([publication], publication.phase)
    |> limit(1)
    |> repo.one()
  end

  defp do_record(repo, tenant_id, publication, lineage) do
    existing =
      ReplyPublication
      |> where(
        [schema],
        schema.tenant_id == ^tenant_id and schema.dedupe_key == ^publication.dedupe_key
      )
      |> lock("FOR UPDATE")
      |> repo.one()

    case existing do
      nil ->
        insert(repo, tenant_id, publication, lineage)

      %ReplyPublication{} = schema ->
        verify_idempotent(repo, schema, publication, lineage)
    end
  end

  defp insert(repo, tenant_id, publication, lineage) do
    changeset =
      ReplyPublication.changeset(
        %ReplyPublication{},
        ReplyPublicationMapper.to_schema_attrs(tenant_id, publication, lineage)
      )

    case repo.insert(changeset, returning: true) do
      {:ok, schema} -> ReplyPublicationMapper.from_schema(schema)
      {:error, changeset} -> repo.rollback(changeset)
    end
  end

  defp verify_idempotent(repo, schema, publication, lineage) do
    expected = ReplyPublicationMapper.to_schema_attrs(schema.tenant_id, publication, lineage)

    exact? =
      schema.publication_id == expected.publication_id and
        schema.causal_unit_id == expected.causal_unit_id and
        schema.phase == expected.phase and schema.state == expected.state and
        schema.dedupe_key == expected.dedupe_key and schema.body == expected.body and
        ReplyBodyBoundary.equivalent_ref?(schema.body_ref, expected.body_ref) and
        schema.run_ref == expected.run_ref and schema.turn_ref == expected.turn_ref and
        schema.attempt_ref == expected.attempt_ref and
        schema.reply_artifact_ref == expected.reply_artifact_ref and
        schema.next_semantic_ref == expected.next_semantic_ref

    if exact? do
      ReplyPublicationMapper.from_schema(schema)
    else
      repo.rollback(
        {:reply_publication_conflict,
         %{
           dedupe_key: publication.dedupe_key,
           existing_body_hash: ReplyBodyBoundary.body_hash(schema.body_ref),
           replay_body_hash: ReplyBodyBoundary.body_hash(publication.body_ref),
           safe_action: :quarantine_duplicate_replay
         }}
      )
    end
  end

  defp latest_query(repo, tenant_id, causal_unit_id) do
    ReplyPublication
    |> where(
      [publication],
      publication.tenant_id == ^tenant_id and publication.causal_unit_id == ^causal_unit_id
    )
    |> order_by_latest_phase()
    |> limit(1)
    |> repo.one()
  end

  defp order_by_latest_phase(query) do
    order_by(
      query,
      [publication],
      desc:
        fragment(
          "CASE WHEN ? = 'final' THEN 2 WHEN ? = 'provisional' THEN 1 ELSE 0 END",
          publication.phase,
          publication.phase
        ),
      desc: publication.updated_at
    )
  end
end
