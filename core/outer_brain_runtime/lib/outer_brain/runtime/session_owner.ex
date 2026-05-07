defmodule OuterBrain.Runtime.SessionOwner do
  @moduledoc """
  Fenced semantic-session owner helper.
  """

  alias OuterBrain.Contracts.Lease
  alias OuterBrain.Persistence.Store, as: PersistenceStore
  alias OuterBrain.Runtime.LeaseRegistry

  @spec acquire(Agent.agent(), String.t(), String.t(), non_neg_integer(), DateTime.t(), keyword()) ::
          {:ok, :acquired | :renewed, Lease.t()} | {:error, term()}
  def acquire(registry, session_id, holder, epoch, now, opts \\ [])
      when is_binary(session_id) and is_binary(holder) and is_integer(epoch) and epoch >= 0 do
    ttl_seconds = Keyword.get(opts, :ttl_seconds, 30)
    lease_id = Keyword.get(opts, :lease_id, "#{holder}:#{session_id}:#{epoch}")
    lease_store = Keyword.get(opts, :lease_store, PersistenceStore)
    lease_store_opts = Keyword.get(opts, :lease_store_opts, [])

    with {:ok, lease} <-
           Lease.new(%{
             session_id: session_id,
             holder: holder,
             lease_id: lease_id,
             epoch: epoch,
             expires_at: DateTime.add(now, ttl_seconds, :second),
             persistence_profile: Keyword.get(opts, :persistence_profile),
             persistence_posture: Keyword.get(opts, :persistence_posture)
           }),
         {:ok, status, persisted_lease} <- lease_store.acquire_lease(lease, now, lease_store_opts) do
      :ok = LeaseRegistry.mirror(registry, persisted_lease)
      {:ok, status, persisted_lease}
    end
  end
end
