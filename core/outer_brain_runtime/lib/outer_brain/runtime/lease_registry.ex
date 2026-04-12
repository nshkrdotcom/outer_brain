defmodule OuterBrain.Runtime.LeaseRegistry do
  @moduledoc """
  Agent-backed lease registry used to prove fenced semantic-session ownership.
  """

  use Agent

  alias OuterBrain.Contracts.{Fence, Lease}

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    Agent.start_link(fn -> %{} end, name: name)
  end

  @spec acquire(Agent.agent(), Lease.t(), DateTime.t()) ::
          {:ok, :acquired | :renewed, Lease.t()} | {:error, term()}
  def acquire(agent, %Lease{} = candidate, %DateTime{} = now) do
    Agent.get_and_update(agent, fn state ->
      session_id = candidate.session_id

      case Map.get(state, session_id) do
        nil ->
          {{:ok, :acquired, candidate}, Map.put(state, session_id, candidate)}

        %Lease{} = current
        when current.holder == candidate.holder and current.lease_id == candidate.lease_id and
               current.epoch == candidate.epoch ->
          {{:ok, :renewed, candidate}, Map.put(state, session_id, candidate)}

        %Lease{} = current ->
          handle_competing_lease(state, session_id, current, candidate, now)
      end
    end)
  end

  @spec current_fence(Agent.agent(), String.t()) :: Fence.t() | nil
  def current_fence(agent, session_id) when is_binary(session_id) do
    Agent.get(agent, fn state ->
      state
      |> Map.get(session_id)
      |> case do
        nil -> nil
        lease -> Fence.from_lease(lease)
      end
    end)
  end

  defp handle_competing_lease(state, session_id, current, candidate, now) do
    if Lease.expired?(current, now) do
      take_or_reject_stale_lease(state, session_id, current, candidate)
    else
      {{:error, {:held_by_other, Fence.from_lease(current)}}, state}
    end
  end

  defp take_or_reject_stale_lease(state, session_id, current, candidate) do
    if candidate.epoch > current.epoch do
      {{:ok, :acquired, candidate}, Map.put(state, session_id, candidate)}
    else
      {{:error, {:stale_epoch, Fence.from_lease(current)}}, state}
    end
  end
end
