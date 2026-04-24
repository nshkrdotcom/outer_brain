defmodule OuterBrain.Persistence.Store do
  @moduledoc """
  Canonical durability API for restart-critical OuterBrain rows.
  """

  import Ecto.Query

  alias OuterBrain.Contracts.{Fence, Lease, ReplyBodyBoundary, SemanticFailure}

  alias OuterBrain.Journal.Tables.{
    RecoveryTaskRecord,
    ReplyPublicationRecord,
    SemanticJournalEntryRecord
  }

  alias OuterBrain.Persistence.Repo

  alias OuterBrain.Persistence.Schemas.{
    RecoveryTask,
    ReplyPublication,
    SemanticJournalEntry,
    SemanticSessionLease
  }

  @semantic_failure_entry_type "semantic_failure"

  @spec acquire_lease(Lease.t(), DateTime.t(), keyword()) ::
          {:ok, :acquired | :renewed, Lease.t()} | {:error, term()}
  def acquire_lease(%Lease{} = candidate, %DateTime{} = now, opts \\ []) do
    repo = repo(opts)

    case repo.transaction(fn -> do_acquire_lease(repo, candidate, now) end) do
      {:ok, {:ok, status, lease}} -> {:ok, status, lease}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec fetch_current_lease(String.t(), keyword()) :: {:ok, Lease.t()} | :error
  def fetch_current_lease(session_id, opts \\ []) when is_binary(session_id) do
    repo = repo(opts)

    case repo.get_by(SemanticSessionLease, session_id: session_id) do
      nil -> :error
      lease -> {:ok, schema_to_lease(lease)}
    end
  end

  @spec append_semantic_journal_entry(SemanticJournalEntryRecord.t(), keyword()) ::
          {:ok, SemanticJournalEntryRecord.t()} | {:error, Ecto.Changeset.t()}
  def append_semantic_journal_entry(%SemanticJournalEntryRecord{} = entry, opts \\ []) do
    repo = repo(opts)

    %SemanticJournalEntry{}
    |> SemanticJournalEntry.changeset(%{
      entry_id: entry.entry_id,
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

  @spec journal_entries(String.t(), keyword()) :: [SemanticJournalEntryRecord.t()]
  def journal_entries(session_id, opts \\ []) when is_binary(session_id) do
    repo = repo(opts)

    SemanticJournalEntry
    |> where([entry], entry.session_id == ^session_id)
    |> order_by([entry], asc: entry.recorded_at, asc: entry.inserted_at)
    |> repo.all()
    |> Enum.map(&schema_to_journal_entry/1)
  end

  @spec record_recovery_task(RecoveryTaskRecord.t(), keyword()) ::
          {:ok, RecoveryTaskRecord.t()} | {:error, Ecto.Changeset.t()}
  def record_recovery_task(%RecoveryTaskRecord{} = task, opts \\ []) do
    repo = repo(opts)

    changeset =
      RecoveryTask.changeset(%RecoveryTask{}, %{
        task_id: task.task_id,
        session_id: task.session_id,
        reason: Atom.to_string(task.reason),
        status: task.status
      })

    case repo.insert(changeset,
           on_conflict: [set: [reason: Atom.to_string(task.reason), status: task.status]],
           conflict_target: :task_id
         ) do
      {:ok, _schema} -> {:ok, task}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @spec pending_recovery_tasks(String.t(), keyword()) :: [RecoveryTaskRecord.t()]
  def pending_recovery_tasks(session_id, opts \\ []) when is_binary(session_id) do
    repo = repo(opts)

    RecoveryTask
    |> where([task], task.session_id == ^session_id and task.status == :pending)
    |> order_by([task], asc: task.inserted_at)
    |> repo.all()
    |> Enum.map(&schema_to_recovery_task/1)
  end

  @spec record_reply_publication(ReplyPublicationRecord.t(), keyword()) ::
          {:ok, ReplyPublicationRecord.t()} | {:error, Ecto.Changeset.t() | term()}
  def record_reply_publication(%ReplyPublicationRecord{} = publication, opts \\ []) do
    repo = repo(opts)

    case repo.transaction(fn -> do_record_reply_publication(repo, publication) end) do
      {:ok, publication} -> {:ok, publication}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec reply_publications(String.t(), keyword()) :: [ReplyPublicationRecord.t()]
  def reply_publications(causal_unit_id, opts \\ []) when is_binary(causal_unit_id) do
    repo = repo(opts)

    ReplyPublication
    |> where([publication], publication.causal_unit_id == ^causal_unit_id)
    |> order_by([publication], asc: publication.inserted_at, asc: publication.publication_id)
    |> repo.all()
    |> Enum.map(&schema_to_reply_publication/1)
  end

  @spec latest_publication(String.t(), keyword()) :: ReplyPublicationRecord.t() | nil
  def latest_publication(causal_unit_id, opts \\ []) when is_binary(causal_unit_id) do
    repo = repo(opts)

    ReplyPublication
    |> where([publication], publication.causal_unit_id == ^causal_unit_id)
    |> order_by(
      [publication],
      desc:
        fragment(
          "CASE WHEN ? = 'final' THEN 2 WHEN ? = 'provisional' THEN 1 ELSE 0 END",
          publication.phase,
          publication.phase
        ),
      desc: publication.updated_at
    )
    |> limit(1)
    |> repo.one()
    |> case do
      nil -> nil
      schema -> schema_to_reply_publication(schema)
    end
  end

  @spec record_semantic_failure(SemanticFailure.t(), keyword()) ::
          {:ok, SemanticFailure.t()} | {:error, term()}
  def record_semantic_failure(%SemanticFailure{} = failure, opts \\ []) do
    repo = repo(opts)
    recorded_at = Keyword.get(opts, :recorded_at, DateTime.utc_now())
    payload = SemanticFailure.to_payload(failure)

    changeset =
      SemanticJournalEntry.changeset(%SemanticJournalEntry{}, %{
        entry_id: SemanticFailure.journal_entry_id(failure),
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

  @spec semantic_failure_entries(String.t(), keyword()) :: [SemanticFailure.t()]
  def semantic_failure_entries(session_id, opts \\ []) when is_binary(session_id) do
    repo = repo(opts)

    SemanticJournalEntry
    |> where(
      [entry],
      entry.session_id == ^session_id and entry.entry_type == ^@semantic_failure_entry_type
    )
    |> order_by([entry], asc: entry.recorded_at, asc: entry.inserted_at)
    |> repo.all()
    |> Enum.map(&semantic_failure_from_schema!/1)
  end

  @spec latest_publication_phase(String.t(), keyword()) :: :final | :provisional | nil
  def latest_publication_phase(causal_unit_id, opts \\ []) when is_binary(causal_unit_id) do
    repo = repo(opts)

    ReplyPublication
    |> where([publication], publication.causal_unit_id == ^causal_unit_id)
    |> order_by(
      [publication],
      desc:
        fragment(
          "CASE WHEN ? = 'final' THEN 2 WHEN ? = 'provisional' THEN 1 ELSE 0 END",
          publication.phase,
          publication.phase
        ),
      desc: publication.updated_at
    )
    |> select([publication], publication.phase)
    |> limit(1)
    |> repo.one()
  end

  defp do_record_reply_publication(repo, publication) do
    existing =
      ReplyPublication
      |> where([schema], schema.dedupe_key == ^publication.dedupe_key)
      |> lock("FOR UPDATE")
      |> repo.one()

    case existing do
      nil ->
        insert_reply_publication(repo, publication)

      %ReplyPublication{} = schema ->
        update_idempotent_reply_publication(repo, schema, publication)
    end
  end

  defp insert_reply_publication(repo, publication) do
    changeset =
      ReplyPublication.changeset(%ReplyPublication{}, reply_publication_attrs(publication))

    case repo.insert(changeset, returning: true) do
      {:ok, schema} -> schema_to_reply_publication(schema)
      {:error, changeset} -> repo.rollback(changeset)
    end
  end

  defp update_idempotent_reply_publication(repo, schema, publication) do
    if ReplyBodyBoundary.equivalent_ref?(schema.body_ref, publication.body_ref) do
      attrs =
        publication
        |> reply_publication_attrs()
        |> Map.put(:publication_id, schema.publication_id)

      changeset = ReplyPublication.changeset(schema, attrs)

      case repo.update(changeset) do
        {:ok, schema} -> schema_to_reply_publication(schema)
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

  defp reply_publication_attrs(publication) do
    %{
      publication_id: publication.publication_id,
      causal_unit_id: publication.causal_unit_id,
      phase: publication.phase,
      state: publication.state,
      dedupe_key: publication.dedupe_key,
      body: publication.body,
      body_ref: publication.body_ref
    }
  end

  defp do_acquire_lease(repo, candidate, now) do
    current =
      SemanticSessionLease
      |> where([lease], lease.session_id == ^candidate.session_id)
      |> lock("FOR UPDATE")
      |> repo.one()

    case current do
      nil ->
        persist_new_lease(repo, candidate, :acquired)

      %SemanticSessionLease{} = persisted ->
        current_lease = schema_to_lease(persisted)

        cond do
          same_lease?(current_lease, candidate) ->
            persist_existing_lease(repo, persisted, candidate, :renewed)

          Lease.expired?(current_lease, now) and candidate.epoch > current_lease.epoch ->
            persist_existing_lease(repo, persisted, candidate, :acquired)

          Lease.expired?(current_lease, now) ->
            repo.rollback({:stale_epoch, Fence.from_lease(current_lease)})

          true ->
            repo.rollback({:held_by_other, Fence.from_lease(current_lease)})
        end
    end
  end

  defp persist_new_lease(repo, candidate, status) do
    changeset =
      SemanticSessionLease.changeset(%SemanticSessionLease{}, %{
        row_id: row_id(candidate.session_id),
        session_id: candidate.session_id,
        holder: candidate.holder,
        lease_id: candidate.lease_id,
        epoch: candidate.epoch,
        expires_at: candidate.expires_at
      })

    case repo.insert(changeset) do
      {:ok, _schema} -> {:ok, status, candidate}
      {:error, changeset} -> repo.rollback(changeset)
    end
  end

  defp persist_existing_lease(repo, persisted, candidate, status) do
    changeset =
      SemanticSessionLease.changeset(persisted, %{
        holder: candidate.holder,
        lease_id: candidate.lease_id,
        epoch: candidate.epoch,
        expires_at: candidate.expires_at
      })

    case repo.update(changeset) do
      {:ok, _schema} -> {:ok, status, candidate}
      {:error, changeset} -> repo.rollback(changeset)
    end
  end

  defp same_lease?(current, candidate) do
    current.holder == candidate.holder and current.lease_id == candidate.lease_id and
      current.epoch == candidate.epoch
  end

  defp schema_to_lease(schema) do
    %Lease{
      session_id: schema.session_id,
      holder: schema.holder,
      lease_id: schema.lease_id,
      epoch: schema.epoch,
      expires_at: schema.expires_at
    }
  end

  defp schema_to_journal_entry(schema) do
    %SemanticJournalEntryRecord{
      entry_id: schema.entry_id,
      session_id: schema.session_id,
      causal_unit_id: schema.causal_unit_id,
      entry_type: schema.entry_type,
      recorded_at: schema.recorded_at,
      payload: schema.payload
    }
  end

  defp schema_to_recovery_task(schema) do
    %RecoveryTaskRecord{
      task_id: schema.task_id,
      session_id: schema.session_id,
      reason: String.to_existing_atom(schema.reason),
      status: schema.status
    }
  end

  defp schema_to_reply_publication(schema) do
    %ReplyPublicationRecord{
      publication_id: schema.publication_id,
      causal_unit_id: schema.causal_unit_id,
      phase: schema.phase,
      state: schema.state,
      dedupe_key: schema.dedupe_key,
      body: schema.body,
      body_ref: schema.body_ref
    }
  end

  defp semantic_failure_from_schema!(schema) do
    case SemanticFailure.from_payload(schema.payload) do
      {:ok, failure} ->
        failure

      {:error, reason} ->
        raise ArgumentError, "invalid semantic failure payload: #{inspect(reason)}"
    end
  end

  defp repo(opts), do: Keyword.get(opts, :repo, Repo)

  defp row_id(session_id), do: "lease:#{session_id}"
end
