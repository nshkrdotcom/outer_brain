defmodule OuterBrain.Persistence.Store do
  @moduledoc """
  Canonical durability API for restart-critical OuterBrain rows.

  This module is the public facade. Profile policy, option parsing, row
  mapping, and Ecto repository operations live in focused modules under
  `OuterBrain.Persistence`.
  """

  alias GroundPlane.Contracts.ArtifactDescriptor
  alias OuterBrain.Contracts.{Lease, SemanticContextProvenance, SemanticFailure}

  alias OuterBrain.Journal.Tables.{
    RecoveryTaskRecord,
    ReplyPublicationRecord,
    SemanticJournalEntryRecord
  }

  alias OuterBrain.Persistence.{
    ArtifactDescriptorRepository,
    JournalRepository,
    LeaseRepository,
    ProfilePolicy,
    RecoveryTaskRepository,
    ReplyPublicationRepository,
    SemanticContextRepository,
    SemanticFailureRepository,
    TenantOptions
  }

  @spec preflight(keyword() | map()) :: :ok | {:error, term()}
  def preflight(opts \\ []), do: ProfilePolicy.preflight(opts)

  @doc """
  Atomically records immutable artifact metadata and the semantic provenance
  fact that refers to it.
  """
  @spec record_semantic_context(
          SemanticContextProvenance.t(),
          ArtifactDescriptor.t(),
          keyword()
        ) :: {:ok, SemanticContextProvenance.t()} | {:error, term()}
  def record_semantic_context(
        %SemanticContextProvenance{} = provenance,
        %ArtifactDescriptor{} = descriptor,
        opts \\ []
      ) do
    repo = TenantOptions.repo(opts)
    tenant_ref = TenantOptions.tenant_id!(opts)

    case repo.transaction(fn ->
           with {:ok, _descriptor} <-
                  ArtifactDescriptorRepository.record(repo, tenant_ref, descriptor),
                {:ok, provenance} <-
                  SemanticContextRepository.record(
                    repo,
                    tenant_ref,
                    provenance,
                    descriptor.artifact_ref
                  ) do
             provenance
           else
             {:error, reason} -> repo.rollback(reason)
           end
         end) do
      {:ok, provenance} -> {:ok, provenance}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec fetch_semantic_context(String.t(), String.t(), keyword()) ::
          {:ok, SemanticContextRepository.record()} | :error
  def fetch_semantic_context(tenant_ref, semantic_ref, opts \\ [])
      when is_binary(tenant_ref) and is_binary(semantic_ref) do
    opts
    |> TenantOptions.repo()
    |> SemanticContextRepository.fetch(tenant_ref, semantic_ref)
  end

  @spec search_semantic_contexts(String.t(), String.t(), keyword()) ::
          [SemanticContextRepository.record()]
  def search_semantic_contexts(tenant_ref, query, opts \\ [])
      when is_binary(tenant_ref) and is_binary(query) do
    opts
    |> TenantOptions.repo()
    |> SemanticContextRepository.search(tenant_ref, query, Keyword.get(opts, :limit, 20))
  end

  @spec fetch_artifact_descriptor(String.t(), String.t(), keyword()) ::
          {:ok, ArtifactDescriptor.t()} | :error
  def fetch_artifact_descriptor(tenant_ref, artifact_ref, opts \\ [])
      when is_binary(tenant_ref) and is_binary(artifact_ref) do
    opts
    |> TenantOptions.repo()
    |> ArtifactDescriptorRepository.fetch(tenant_ref, artifact_ref)
  end

  @spec acquire_lease(Lease.t(), DateTime.t(), keyword()) ::
          {:ok, :acquired | :renewed, Lease.t()} | {:error, term()}
  def acquire_lease(%Lease{} = candidate, %DateTime{} = now, opts \\ []) do
    opts
    |> TenantOptions.repo()
    |> LeaseRepository.acquire(TenantOptions.tenant_id!(opts), candidate, now)
  end

  @spec fetch_current_lease(String.t(), String.t(), keyword()) :: {:ok, Lease.t()} | :error
  def fetch_current_lease(tenant_id, session_id, opts \\ [])
      when is_binary(tenant_id) and is_binary(session_id) do
    opts
    |> TenantOptions.repo()
    |> LeaseRepository.fetch_current(tenant_id, session_id)
  end

  @spec append_semantic_journal_entry(SemanticJournalEntryRecord.t(), keyword()) ::
          {:ok, SemanticJournalEntryRecord.t()} | {:error, Ecto.Changeset.t() | term()}
  def append_semantic_journal_entry(%SemanticJournalEntryRecord{} = entry, opts \\ []) do
    opts
    |> TenantOptions.repo()
    |> JournalRepository.append(TenantOptions.tenant_id!(opts), entry)
  end

  @spec journal_entries(String.t(), String.t(), keyword()) :: [SemanticJournalEntryRecord.t()]
  def journal_entries(tenant_id, session_id, opts \\ [])
      when is_binary(tenant_id) and is_binary(session_id) do
    opts
    |> TenantOptions.repo()
    |> JournalRepository.list(tenant_id, session_id)
  end

  @spec record_recovery_task(RecoveryTaskRecord.t(), keyword()) ::
          {:ok, RecoveryTaskRecord.t()} | {:error, Ecto.Changeset.t() | term()}
  def record_recovery_task(%RecoveryTaskRecord{} = task, opts \\ []) do
    opts
    |> TenantOptions.repo()
    |> RecoveryTaskRepository.record(TenantOptions.tenant_id!(opts), task)
  end

  @spec pending_recovery_tasks(String.t(), String.t(), keyword()) :: [RecoveryTaskRecord.t()]
  def pending_recovery_tasks(tenant_id, session_id, opts \\ [])
      when is_binary(tenant_id) and is_binary(session_id) do
    opts
    |> TenantOptions.repo()
    |> RecoveryTaskRepository.pending(tenant_id, session_id)
  end

  @spec record_reply_publication(ReplyPublicationRecord.t(), keyword()) ::
          {:ok, ReplyPublicationRecord.t()} | {:error, Ecto.Changeset.t() | term()}
  def record_reply_publication(%ReplyPublicationRecord{} = publication, opts \\ []) do
    opts
    |> TenantOptions.repo()
    |> ReplyPublicationRepository.record(TenantOptions.tenant_id!(opts), publication)
  end

  @spec reply_publications(String.t(), String.t(), keyword()) :: [ReplyPublicationRecord.t()]
  def reply_publications(tenant_id, causal_unit_id, opts \\ [])
      when is_binary(tenant_id) and is_binary(causal_unit_id) do
    opts
    |> TenantOptions.repo()
    |> ReplyPublicationRepository.list(tenant_id, causal_unit_id)
  end

  @spec latest_publication(String.t(), String.t(), keyword()) :: ReplyPublicationRecord.t() | nil
  def latest_publication(tenant_id, causal_unit_id, opts \\ [])
      when is_binary(tenant_id) and is_binary(causal_unit_id) do
    opts
    |> TenantOptions.repo()
    |> ReplyPublicationRepository.latest(tenant_id, causal_unit_id)
  end

  @spec latest_publication_phase(String.t(), String.t(), keyword()) :: :final | :provisional | nil
  def latest_publication_phase(tenant_id, causal_unit_id, opts \\ [])
      when is_binary(tenant_id) and is_binary(causal_unit_id) do
    opts
    |> TenantOptions.repo()
    |> ReplyPublicationRepository.latest_phase(tenant_id, causal_unit_id)
  end

  @spec record_semantic_failure(SemanticFailure.t(), keyword()) ::
          {:ok, SemanticFailure.t()} | {:error, term()}
  def record_semantic_failure(%SemanticFailure{} = failure, opts \\ []) do
    opts
    |> TenantOptions.repo()
    |> SemanticFailureRepository.record(failure, TenantOptions.recorded_at(opts))
  end

  @spec semantic_failure_entries(String.t(), String.t(), keyword()) :: [SemanticFailure.t()]
  def semantic_failure_entries(tenant_id, session_id, opts \\ [])
      when is_binary(tenant_id) and is_binary(session_id) do
    opts
    |> TenantOptions.repo()
    |> SemanticFailureRepository.list(tenant_id, session_id)
  end
end
