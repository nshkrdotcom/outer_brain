defmodule OuterBrain.Persistence.LeaseRepository do
  @moduledoc false

  import Ecto.Query

  alias OuterBrain.Contracts.{Fence, Lease}
  alias OuterBrain.Persistence.LeaseMapper
  alias OuterBrain.Persistence.Schemas.SemanticSessionLease

  @spec acquire(module(), String.t(), Lease.t(), DateTime.t()) ::
          {:ok, :acquired | :renewed, Lease.t()} | {:error, term()}
  def acquire(repo, tenant_id, %Lease{} = candidate, %DateTime{} = now) do
    case repo.transaction(fn -> do_acquire_lease(repo, tenant_id, candidate, now) end) do
      {:ok, {:ok, status, lease}} -> {:ok, status, lease}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec fetch_current(module(), String.t(), String.t()) :: {:ok, Lease.t()} | :error
  def fetch_current(repo, tenant_id, session_id)
      when is_binary(tenant_id) and is_binary(session_id) do
    case repo.get_by(SemanticSessionLease, tenant_id: tenant_id, session_id: session_id) do
      nil -> :error
      lease -> {:ok, LeaseMapper.from_schema(lease)}
    end
  end

  defp do_acquire_lease(repo, tenant_id, candidate, now) do
    current =
      SemanticSessionLease
      |> where(
        [lease],
        lease.tenant_id == ^tenant_id and lease.session_id == ^candidate.session_id
      )
      |> lock("FOR UPDATE")
      |> repo.one()

    case current do
      nil ->
        persist_new_lease(repo, tenant_id, candidate, :acquired)

      %SemanticSessionLease{} = persisted ->
        current_lease = LeaseMapper.from_schema(persisted)

        cond do
          same_lease?(current_lease, candidate) ->
            persist_existing_lease(repo, persisted, tenant_id, candidate, :renewed)

          Lease.expired?(current_lease, now) and candidate.epoch > current_lease.epoch ->
            persist_existing_lease(repo, persisted, tenant_id, candidate, :acquired)

          Lease.expired?(current_lease, now) ->
            repo.rollback({:stale_epoch, Fence.from_lease(current_lease)})

          true ->
            repo.rollback({:held_by_other, Fence.from_lease(current_lease)})
        end
    end
  end

  defp persist_new_lease(repo, tenant_id, candidate, status) do
    changeset =
      SemanticSessionLease.changeset(%SemanticSessionLease{}, %{
        row_id: row_id(tenant_id, candidate.session_id),
        tenant_id: tenant_id,
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

  defp persist_existing_lease(repo, persisted, tenant_id, candidate, status) do
    changeset =
      SemanticSessionLease.changeset(persisted, %{
        tenant_id: tenant_id,
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

  defp row_id(tenant_id, session_id), do: "lease:#{tenant_id}:#{session_id}"
end
