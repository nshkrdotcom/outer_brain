defmodule OuterBrain.Runtime.LeaseRegistry do
  @moduledoc """
  Supervised hot mirror of canonical semantic-session lease ownership.

  Canonical lease truth lives in the persistence store. This registry is a
  runtime mirror for active owners and always reports whether a read is fresh,
  stale, or missing.
  """

  use GenServer

  alias OuterBrain.Contracts.{Fence, Lease}
  alias OuterBrain.Persistence.Store, as: PersistenceStore

  @type registry :: GenServer.server()
  @type read_posture :: :mirror_fresh | :mirror_stale | :missing

  @event_prefix [:outer_brain, :runtime, :lease_registry]

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, %{}, name: name)
  end

  @impl true
  def init(state) when is_map(state), do: {:ok, state}

  @spec acquire(registry(), Lease.t(), DateTime.t()) ::
          {:ok, :acquired | :renewed, Lease.t()} | {:error, term()}
  def acquire(registry, %Lease{} = candidate, %DateTime{} = now) do
    GenServer.call(registry, {:acquire, candidate, now})
  end

  @spec current_fence(registry(), String.t()) :: Fence.t() | nil
  def current_fence(registry, session_id) when is_binary(session_id) do
    GenServer.call(registry, {:current_fence, session_id})
  end

  @spec current_fence_with_posture(registry(), String.t(), DateTime.t()) ::
          {:ok, Fence.t(), :mirror_fresh}
          | {:error, {:mirror_stale, Fence.t()}}
          | {:error, :missing, :missing}
  def current_fence_with_posture(registry, session_id, %DateTime{} = now)
      when is_binary(session_id) do
    GenServer.call(registry, {:current_fence_with_posture, session_id, now})
  end

  @spec mirror(registry(), Lease.t()) :: :ok
  def mirror(registry, %Lease{} = lease) do
    GenServer.call(registry, {:mirror, lease})
  end

  @spec reload_from_canonical(registry(), module(), String.t(), String.t(), keyword()) ::
          {:ok, Lease.t(), :canonical} | {:error, term()} | :error
  def reload_from_canonical(
        registry,
        lease_store \\ PersistenceStore,
        tenant_id,
        session_id,
        opts \\ []
      )
      when is_binary(tenant_id) and is_binary(session_id) do
    lease_store_opts =
      opts |> Keyword.get(:lease_store_opts, []) |> Keyword.put_new(:tenant_id, tenant_id)

    case lease_store.fetch_current_lease(tenant_id, session_id, lease_store_opts) do
      {:ok, %Lease{} = lease} ->
        :ok = mirror(registry, lease)
        {:ok, lease, :canonical}

      other ->
        other
    end
  end

  @spec expire(registry(), String.t(), DateTime.t()) ::
          {:ok, :expired, Lease.t()} | {:ok, :not_expired, Fence.t()} | {:error, :missing}
  def expire(registry, session_id, %DateTime{} = now) when is_binary(session_id) do
    GenServer.call(registry, {:expire, session_id, now})
  end

  @spec release(registry(), String.t(), String.t()) ::
          {:ok, :released, Lease.t()} | {:error, :missing | {:lease_mismatch, Fence.t()}}
  def release(registry, session_id, lease_id)
      when is_binary(session_id) and is_binary(lease_id) do
    GenServer.call(registry, {:release, session_id, lease_id})
  end

  @impl true
  def handle_call({:acquire, %Lease{} = candidate, %DateTime{} = now}, _from, state) do
    session_id = candidate.session_id

    {reply, next_state, event_status} =
      case Map.get(state, session_id) do
        nil ->
          {{:ok, :acquired, candidate}, Map.put(state, session_id, candidate), :acquired}

        %Lease{} = current
        when current.holder == candidate.holder and current.lease_id == candidate.lease_id and
               current.epoch == candidate.epoch ->
          {{:ok, :renewed, candidate}, Map.put(state, session_id, candidate), :renewed}

        %Lease{} = current ->
          handle_competing_lease(state, session_id, current, candidate, now)
      end

    emit_lifecycle(event_status, candidate, reply)
    {:reply, reply, next_state}
  end

  def handle_call({:current_fence, session_id}, _from, state) do
    reply =
      state
      |> Map.get(session_id)
      |> fence_or_nil()

    {:reply, reply, state}
  end

  def handle_call({:current_fence_with_posture, session_id, %DateTime{} = now}, _from, state) do
    reply =
      case Map.get(state, session_id) do
        nil ->
          {:error, :missing, :missing}

        %Lease{} = lease ->
          fence = Fence.from_lease(lease)

          if Lease.expired?(lease, now) do
            {:error, {:mirror_stale, fence}}
          else
            {:ok, fence, :mirror_fresh}
          end
      end

    {:reply, reply, state}
  end

  def handle_call({:mirror, %Lease{} = lease}, _from, state) do
    {:reply, :ok, Map.put(state, lease.session_id, lease)}
  end

  def handle_call({:expire, session_id, %DateTime{} = now}, _from, state) do
    {reply, next_state} =
      case Map.get(state, session_id) do
        nil ->
          {{:error, :missing}, state}

        %Lease{} = lease ->
          if Lease.expired?(lease, now) do
            {{:ok, :expired, lease}, Map.delete(state, session_id)}
          else
            {{:ok, :not_expired, Fence.from_lease(lease)}, state}
          end
      end

    emit_expire(session_id, reply)
    {:reply, reply, next_state}
  end

  def handle_call({:release, session_id, lease_id}, _from, state) do
    {reply, next_state} =
      case Map.get(state, session_id) do
        nil ->
          {{:error, :missing}, state}

        %Lease{lease_id: ^lease_id} = lease ->
          {{:ok, :released, lease}, Map.delete(state, session_id)}

        %Lease{} = lease ->
          {{:error, {:lease_mismatch, Fence.from_lease(lease)}}, state}
      end

    emit_release(session_id, lease_id, reply)
    {:reply, reply, next_state}
  end

  defp handle_competing_lease(state, session_id, current, candidate, now) do
    if Lease.expired?(current, now) do
      take_or_reject_stale_lease(state, session_id, current, candidate)
    else
      {{:error, {:held_by_other, Fence.from_lease(current)}}, state, :rejected}
    end
  end

  defp take_or_reject_stale_lease(state, session_id, current, candidate) do
    if candidate.epoch > current.epoch do
      {{:ok, :acquired, candidate}, Map.put(state, session_id, candidate), :acquired}
    else
      {{:error, {:stale_epoch, Fence.from_lease(current)}}, state, :rejected}
    end
  end

  defp fence_or_nil(nil), do: nil
  defp fence_or_nil(%Lease{} = lease), do: Fence.from_lease(lease)

  defp emit_lifecycle(:acquired, %Lease{} = lease, reply) do
    emit(:acquire, lease_metadata(lease, :acquired, reply))
  end

  defp emit_lifecycle(:renewed, %Lease{} = lease, reply) do
    emit(:renew, lease_metadata(lease, :renewed, reply))
  end

  defp emit_lifecycle(:rejected, %Lease{} = lease, reply) do
    emit(:reject, lease_metadata(lease, :rejected, reply))
  end

  defp emit_expire(_session_id, {:ok, :expired, %Lease{} = lease}) do
    emit(:expire, lease_metadata(lease, :expired, {:ok, :expired, lease}))
  end

  defp emit_expire(session_id, reply) do
    emit(:expire, %{
      session_id: session_id,
      status: reply_status(reply),
      result: reply_result(reply)
    })
  end

  defp emit_release(_session_id, _lease_id, {:ok, :released, %Lease{} = lease}) do
    emit(:release, lease_metadata(lease, :released, {:ok, :released, lease}))
  end

  defp emit_release(session_id, lease_id, reply) do
    emit(:release, %{
      session_id: session_id,
      lease_id: lease_id,
      status: reply_status(reply),
      result: reply_result(reply)
    })
  end

  defp emit(event, metadata) do
    :telemetry.execute(@event_prefix ++ [event], %{count: 1}, metadata)
  end

  defp lease_metadata(%Lease{} = lease, status, reply) do
    %{
      session_id: lease.session_id,
      holder: lease.holder,
      lease_id: lease.lease_id,
      epoch: lease.epoch,
      status: status,
      result: reply_result(reply)
    }
  end

  defp reply_result({:ok, status, _lease})
       when status in [:acquired, :renewed, :expired, :released],
       do: :ok

  defp reply_result({:ok, :not_expired, _fence}), do: :ok
  defp reply_result({:error, _reason}), do: :error

  defp reply_status({:ok, status, _value}), do: status
  defp reply_status({:error, reason}), do: reason
end
