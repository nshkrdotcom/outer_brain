defmodule OuterBrain.Runtime.SessionOwnerTest do
  use ExUnit.Case, async: false

  alias OuterBrain.Contracts.Lease
  alias OuterBrain.Runtime.{LeaseRegistry, SessionOwner, StreamState, WakeCoordinator}

  setup do
    registry = start_supervised!({LeaseRegistry, name: nil})
    __MODULE__.FakeLeaseStore.reset!()
    %{registry: registry}
  end

  test "one semantic session has exactly one live owner per fence epoch", %{registry: registry} do
    now = DateTime.from_unix!(1_800_000_500)

    assert {:ok, :acquired, lease} =
             SessionOwner.acquire(registry, "session_alpha", "node_a", 1, now,
               ttl_seconds: 30,
               lease_store: __MODULE__.FakeLeaseStore
             )

    assert {:error, {:held_by_other, fence}} =
             SessionOwner.acquire(registry, "session_alpha", "node_b", 1, now,
               ttl_seconds: 30,
               lease_store: __MODULE__.FakeLeaseStore
             )

    assert fence.epoch == 1
    assert fence.holder == "node_a"
    assert fence.persistence_posture.raw_prompt_persistence? == false
    assert lease.epoch == 1

    assert lease.persistence_posture.persistence_profile_ref ==
             "persistence-profile://mickey-mouse"
  end

  test "stale owners can be replaced only after expiry and with a newer epoch", %{
    registry: registry
  } do
    now = DateTime.from_unix!(1_800_000_500)

    assert {:ok, :acquired, _lease} =
             SessionOwner.acquire(registry, "session_alpha", "node_a", 1, now,
               ttl_seconds: 1,
               lease_store: __MODULE__.FakeLeaseStore
             )

    later = DateTime.add(now, 5, :second)

    assert {:error, {:stale_epoch, _fence}} =
             SessionOwner.acquire(registry, "session_alpha", "node_b", 1, later,
               ttl_seconds: 30,
               lease_store: __MODULE__.FakeLeaseStore
             )

    assert {:ok, :acquired, replacement} =
             SessionOwner.acquire(registry, "session_alpha", "node_b", 2, later,
               ttl_seconds: 30,
               lease_store: __MODULE__.FakeLeaseStore
             )

    assert LeaseRegistry.current_fence(registry, "session_alpha").holder == "node_b"
    assert replacement.epoch == 2
  end

  test "wake coordination chooses one follow-up path and stream state distinguishes phases" do
    assert WakeCoordinator.next_follow_up(%{wake_path: :re_deliberate}) == :re_deliberate

    stream_state =
      "session_alpha"
      |> StreamState.provisional("publication_1", persistence_profile: :durable_redacted)
      |> StreamState.finalize("publication_2")

    assert stream_state.phase == :final
    assert stream_state.last_publication_id == "publication_2"
    assert stream_state.persistence_posture.durable? == true
  end

  defmodule FakeLeaseStore do
    @moduledoc false

    alias OuterBrain.Contracts.{Fence, Lease}

    @table :outer_brain_runtime_fake_lease_store

    def acquire_lease(%Lease{} = candidate, %DateTime{} = now, _opts) do
      ensure_table!()

      case :ets.lookup(@table, candidate.session_id) do
        [] ->
          true = :ets.insert(@table, {candidate.session_id, candidate})
          {:ok, :acquired, candidate}

        [{_session_id, %Lease{} = current}]
        when current.holder == candidate.holder and current.lease_id == candidate.lease_id and
               current.epoch == candidate.epoch ->
          true = :ets.insert(@table, {candidate.session_id, candidate})
          {:ok, :renewed, candidate}

        [{_session_id, %Lease{} = current}] ->
          handle_competing_lease(current, candidate, now)
      end
    end

    defp handle_competing_lease(current, candidate, now) do
      if Lease.expired?(current, now) and candidate.epoch > current.epoch do
        true = :ets.insert(@table, {candidate.session_id, candidate})
        {:ok, :acquired, candidate}
      else
        {:error, competing_lease_error(current, now)}
      end
    end

    defp competing_lease_error(current, now) do
      if Lease.expired?(current, now) do
        {:stale_epoch, Fence.from_lease(current)}
      else
        {:held_by_other, Fence.from_lease(current)}
      end
    end

    defp ensure_table! do
      case :ets.whereis(@table) do
        :undefined ->
          :ets.new(@table, [:named_table, :public, :set])

        _table ->
          @table
      end
    end

    def reset! do
      case :ets.whereis(@table) do
        :undefined ->
          :ok

        _table ->
          :ets.delete_all_objects(@table)
          :ok
      end
    end
  end
end
