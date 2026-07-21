defmodule OuterBrain.Persistence.Store do
  @moduledoc """
  Canonical durability API for restart-critical OuterBrain rows.

  This module is the public facade. Profile policy, option parsing, row
  mapping, and Ecto repository operations live in focused modules under
  `OuterBrain.Persistence`.
  """

  alias GroundPlane.Boundary.Codec
  alias GroundPlane.Contracts.ArtifactDescriptor
  alias OuterBrain.Contracts.{Lease, SemanticContextProvenance, SemanticFailure}

  alias OuterBrain.Journal.Tables.{
    RecoveryTaskRecord,
    ReplyPublicationRecord,
    SemanticJournalEntryRecord
  }

  alias OuterBrain.Persistence.{
    ArtifactAccess,
    ArtifactDescriptorRepository,
    ArtifactPayloadRepository,
    JournalRepository,
    LeaseRepository,
    ProfilePolicy,
    RecoveryTaskRepository,
    ReplyPublicationRepository,
    SemanticContextRepository,
    SemanticFailureRepository,
    TenantOptions
  }

  alias OuterBrain.Prompting.ImmutableArtifact

  alias OuterBrain.Prompting.SemanticTurnArtifacts.{
    PromptContext,
    ReplyContinuation
  }

  @spec preflight(keyword() | map()) :: :ok | {:error, term()}
  def preflight(opts \\ []), do: ProfilePolicy.preflight(opts)

  @doc """
  Atomically records the immutable context and prompt-manifest artifacts plus
  their semantic provenance. No metadata-only production route exists.
  """
  @spec record_prompt_context(PromptContext.t(), keyword()) ::
          {:ok, PromptContext.t()} | {:error, term()}
  def record_prompt_context(%PromptContext{} = prompt, opts \\ []) do
    repo = TenantOptions.repo(opts)
    tenant_ref = TenantOptions.tenant_id!(opts)

    case repo.transaction(fn ->
           with :ok <- require_prompt_tenant(prompt, tenant_ref),
                {:ok, _context_artifact} <-
                  record_artifact(repo, tenant_ref, prompt.context_artifact),
                {:ok, _prompt_artifact} <-
                  record_artifact(repo, tenant_ref, prompt.prompt_artifact),
                {:ok, provenance} <-
                  SemanticContextRepository.record(
                    repo,
                    tenant_ref,
                    prompt.provenance,
                    prompt_lineage(prompt)
                  ) do
             %{prompt | provenance: provenance}
           else
             {:error, reason} -> repo.rollback(reason)
           end
         end) do
      {:ok, %PromptContext{} = persisted} -> {:ok, persisted}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Atomically publishes a normalized final assistant reply, the next immutable
  context artifact, its semantic provenance, the publication row, and a safe
  journal fact.
  """
  @spec publish_reply_continuation(ReplyContinuation.t(), keyword()) ::
          {:ok, ReplyContinuation.t()} | {:error, term()}
  def publish_reply_continuation(%ReplyContinuation{} = continuation, opts \\ []) do
    repo = TenantOptions.repo(opts)
    tenant_ref = TenantOptions.tenant_id!(opts)

    case repo.transaction(fn ->
           with :ok <- require_continuation_tenant(continuation, tenant_ref),
                {:ok, previous} <-
                  fetch_required_semantic(repo, tenant_ref, continuation.previous_semantic_ref),
                :ok <- validate_previous_prompt(previous, continuation),
                {:ok, _reply_artifact} <-
                  record_artifact(repo, tenant_ref, continuation.reply_artifact),
                {:ok, _next_context_artifact} <-
                  record_artifact(repo, tenant_ref, continuation.next_context_artifact),
                {:ok, next_provenance} <-
                  SemanticContextRepository.record(
                    repo,
                    tenant_ref,
                    continuation.next_provenance,
                    continuation_lineage(continuation)
                  ),
                publication <-
                  ReplyPublicationRepository.record_in_transaction(
                    repo,
                    tenant_ref,
                    continuation.publication,
                    publication_lineage(continuation)
                  ),
                {:ok, _journal_entry} <-
                  JournalRepository.append(
                    repo,
                    tenant_ref,
                    publication_journal_entry(continuation, publication)
                  ) do
             %{continuation | publication: publication, next_provenance: next_provenance}
           else
             {:error, reason} -> repo.rollback(reason)
             :error -> repo.rollback(:previous_semantic_context_not_found)
           end
         end) do
      {:ok, %ReplyContinuation{} = persisted} -> {:ok, persisted}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec resolve_artifact_payload(String.t(), ArtifactAccess.t() | map() | keyword(), keyword()) ::
          {:ok, %{descriptor: ArtifactDescriptor.t(), payload: binary()}} | {:error, term()}
  def resolve_artifact_payload(artifact_ref, access, opts \\ []) when is_binary(artifact_ref) do
    with {:ok, access} <- ArtifactAccess.new(access) do
      opts
      |> TenantOptions.repo()
      |> ArtifactPayloadRepository.resolve(artifact_ref, access)
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

  defp record_artifact(repo, tenant_ref, %ImmutableArtifact{} = artifact) do
    with {:ok, _descriptor} <-
           ArtifactDescriptorRepository.record(repo, tenant_ref, artifact.descriptor),
         {:ok, artifact} <- ArtifactPayloadRepository.record(repo, tenant_ref, artifact) do
      {:ok, artifact}
    end
  end

  defp prompt_lineage(prompt) do
    %{
      run_ref: prompt.run_ref,
      turn_ref: prompt.turn_ref,
      context_artifact_ref: prompt.context_artifact.descriptor.artifact_ref,
      prompt_artifact_ref: prompt.prompt_artifact.descriptor.artifact_ref,
      model_profile_ref: prompt.model_profile_ref,
      memory_snapshot_refs: prompt.memory_snapshot_refs,
      previous_semantic_ref: prompt.previous_semantic_ref
    }
  end

  defp continuation_lineage(continuation) do
    %{
      run_ref: continuation.run_ref,
      turn_ref: continuation.turn_ref,
      context_artifact_ref: continuation.next_context_artifact.descriptor.artifact_ref,
      prompt_artifact_ref: continuation.prompt_artifact_ref,
      model_profile_ref: continuation.model_profile_ref,
      memory_snapshot_refs: continuation.memory_snapshot_refs,
      previous_semantic_ref: continuation.previous_semantic_ref
    }
  end

  defp publication_lineage(continuation) do
    %{
      run_ref: continuation.run_ref,
      turn_ref: continuation.turn_ref,
      attempt_ref: continuation.attempt_ref,
      reply_artifact_ref: continuation.reply_artifact.descriptor.artifact_ref,
      next_semantic_ref: continuation.next_provenance.semantic_ref
    }
  end

  defp publication_journal_entry(continuation, publication) do
    entry_id =
      Codec.digest(%{
        "publication_id" => publication.publication_id,
        "next_semantic_ref" => continuation.next_provenance.semantic_ref
      })
      |> String.replace_prefix("sha256:", "journal-entry://outer-brain/")

    {:ok, entry} =
      SemanticJournalEntryRecord.new(%{
        entry_id: entry_id,
        session_id: continuation.run_ref,
        causal_unit_id: continuation.turn_ref,
        entry_type: "assistant_reply_published",
        recorded_at: continuation.published_at,
        payload: %{
          "publication_id" => publication.publication_id,
          "attempt_ref" => continuation.attempt_ref,
          "prompt_artifact_ref" => continuation.prompt_artifact_ref,
          "reply_artifact_ref" => continuation.reply_artifact.descriptor.artifact_ref,
          "next_context_artifact_ref" =>
            continuation.next_context_artifact.descriptor.artifact_ref,
          "next_semantic_ref" => continuation.next_provenance.semantic_ref
        }
      })

    entry
  end

  defp require_prompt_tenant(prompt, tenant_ref) do
    if prompt.provenance.tenant_ref == tenant_ref,
      do: :ok,
      else: {:error, :prompt_context_tenant_mismatch}
  end

  defp require_continuation_tenant(continuation, tenant_ref) do
    if continuation.next_provenance.tenant_ref == tenant_ref,
      do: :ok,
      else: {:error, :reply_continuation_tenant_mismatch}
  end

  defp fetch_required_semantic(repo, tenant_ref, semantic_ref) do
    case SemanticContextRepository.fetch(repo, tenant_ref, semantic_ref) do
      {:ok, record} -> {:ok, record}
      :error -> {:error, :previous_semantic_context_not_found}
    end
  end

  defp validate_previous_prompt(previous, continuation) do
    cond do
      previous.lineage.prompt_artifact_ref != continuation.prompt_artifact_ref ->
        {:error, :reply_prompt_artifact_mismatch}

      previous.lineage.run_ref != continuation.run_ref ->
        {:error, :reply_run_ref_mismatch}

      previous.lineage.turn_ref != continuation.turn_ref ->
        {:error, :reply_turn_ref_mismatch}

      true ->
        :ok
    end
  end
end
