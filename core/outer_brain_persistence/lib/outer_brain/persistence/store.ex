defmodule OuterBrain.Persistence.Store do
  @moduledoc """
  Canonical durability API for restart-critical OuterBrain rows.

  This module is the public facade. Profile policy, option parsing, row
  mapping, and Ecto repository operations live in focused modules under
  `OuterBrain.Persistence`.
  """

  alias OuterBrain.Contracts.{Lease, SemanticFailure}

  alias OuterBrain.Journal.Tables.{
    RecoveryTaskRecord,
    ReplyPublicationRecord,
    SemanticJournalEntryRecord
  }

  alias OuterBrain.Persistence.{
    JournalRepository,
    LeaseRepository,
    ProfilePolicy,
    RecoveryTaskRepository,
    ReplyPublicationRepository,
    SemanticFailureRepository,
    TenantOptions
  }

  @spec preflight(keyword() | map()) :: :ok | {:error, term()}
  def preflight(opts \\ []), do: ProfilePolicy.preflight(opts)

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
          {:ok, SemanticJournalEntryRecord.t()} | {:error, Ecto.Changeset.t()}
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
