defmodule OuterBrain.Persistence.ReplyPublicationRepository do
  @moduledoc false

  import Ecto.Query

  alias OuterBrain.Contracts.ReplyBodyBoundary
  alias OuterBrain.Journal.Tables.ReplyPublicationRecord
  alias OuterBrain.Persistence.ReplyPublicationMapper
  alias OuterBrain.Persistence.Schemas.ReplyPublication

  @spec record(module(), String.t(), ReplyPublicationRecord.t()) ::
          {:ok, ReplyPublicationRecord.t()} | {:error, Ecto.Changeset.t() | term()}
  def record(repo, tenant_id, %ReplyPublicationRecord{} = publication) do
    case repo.transaction(fn -> do_record(repo, tenant_id, publication) end) do
      {:ok, publication} -> {:ok, publication}
      {:error, reason} -> {:error, reason}
    end
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

  defp do_record(repo, tenant_id, publication) do
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
        insert(repo, tenant_id, publication)

      %ReplyPublication{} = schema ->
        update_idempotent(repo, schema, tenant_id, publication)
    end
  end

  defp insert(repo, tenant_id, publication) do
    changeset =
      ReplyPublication.changeset(
        %ReplyPublication{},
        ReplyPublicationMapper.to_schema_attrs(tenant_id, publication)
      )

    case repo.insert(changeset, returning: true) do
      {:ok, schema} -> ReplyPublicationMapper.from_schema(schema)
      {:error, changeset} -> repo.rollback(changeset)
    end
  end

  defp update_idempotent(repo, schema, tenant_id, publication) do
    if ReplyBodyBoundary.equivalent_ref?(schema.body_ref, publication.body_ref) do
      attrs =
        tenant_id
        |> ReplyPublicationMapper.to_schema_attrs(publication)
        |> Map.put(:publication_id, schema.publication_id)

      changeset = ReplyPublication.changeset(schema, attrs)

      case repo.update(changeset) do
        {:ok, schema} -> ReplyPublicationMapper.from_schema(schema)
        {:error, changeset} -> repo.rollback(changeset)
      end
    else
      repo.rollback(
        {:reply_publication_body_ref_mismatch,
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
