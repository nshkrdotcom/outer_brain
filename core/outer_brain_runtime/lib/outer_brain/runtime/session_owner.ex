defmodule OuterBrain.Runtime.SessionOwner do
  @moduledoc """
  Fenced semantic-session owner helper.
  """

  alias OuterBrain.Contracts.Lease
  alias OuterBrain.Runtime.LeaseRegistry

  @spec acquire(Agent.agent(), String.t(), String.t(), non_neg_integer(), DateTime.t(), keyword()) ::
          {:ok, :acquired | :renewed, Lease.t()} | {:error, term()}
  def acquire(registry, session_id, holder, epoch, now, opts \\ [])
      when is_binary(session_id) and is_binary(holder) and is_integer(epoch) and epoch >= 0 do
    ttl_seconds = Keyword.get(opts, :ttl_seconds, 30)
    lease_id = Keyword.get(opts, :lease_id, "#{holder}:#{session_id}:#{epoch}")

    with {:ok, lease} <-
           Lease.new(%{
             session_id: session_id,
             holder: holder,
             lease_id: lease_id,
             epoch: epoch,
             expires_at: DateTime.add(now, ttl_seconds, :second)
           }) do
      LeaseRegistry.acquire(registry, lease, now)
    end
  end
end
