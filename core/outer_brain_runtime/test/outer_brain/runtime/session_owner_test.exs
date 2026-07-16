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
             SessionOwner.acquire_with_store(
               registry,
               "session_alpha",
               "node_a",
               1,
               now,
               __MODULE__.FakeLeaseStore,
               tenant_id: "tenant://runtime/a",
               ttl_seconds: 30
             )

    assert {:error, {:held_by_other, fence}} =
             SessionOwner.acquire_with_store(
               registry,
               "session_alpha",
               "node_b",
               1,
               now,
               __MODULE__.FakeLeaseStore,
               tenant_id: "tenant://runtime/a",
               ttl_seconds: 30
             )

    assert fence.epoch == 1
    assert fence.holder == "node_a"
    assert fence.persistence_posture.raw_prompt_persistence? == false
    assert lease.epoch == 1

    assert lease.persistence_posture.persistence_profile_ref ==
             "persistence-profile://outer-brain-durable-redacted"
  end

  test "stale owners can be replaced only after expiry and with a newer epoch", %{
    registry: registry
  } do
    now = DateTime.from_unix!(1_800_000_500)

    assert {:ok, :acquired, _lease} =
             SessionOwner.acquire_with_store(
               registry,
               "session_alpha",
               "node_a",
               1,
               now,
               __MODULE__.FakeLeaseStore,
               tenant_id: "tenant://runtime/a",
               ttl_seconds: 1
             )

    later = DateTime.add(now, 5, :second)

    assert {:error, {:stale_epoch, _fence}} =
             SessionOwner.acquire_with_store(
               registry,
               "session_alpha",
               "node_b",
               1,
               later,
               __MODULE__.FakeLeaseStore,
               tenant_id: "tenant://runtime/a",
               ttl_seconds: 30
             )

    assert {:ok, :acquired, replacement} =
             SessionOwner.acquire_with_store(
               registry,
               "session_alpha",
               "node_b",
               2,
               later,
               __MODULE__.FakeLeaseStore,
               tenant_id: "tenant://runtime/a",
               ttl_seconds: 30
             )

    assert LeaseRegistry.current_fence(registry, "session_alpha").holder == "node_b"
    assert replacement.epoch == 2
  end

  test "lease registry child spec restarts under a supervisor with empty mirror state" do
    {:ok, supervisor} =
      Supervisor.start_link([{LeaseRegistry, name: nil}], strategy: :one_for_one)

    on_exit(fn ->
      if Process.alive?(supervisor), do: Supervisor.stop(supervisor)
    end)

    [{_id, registry, _type, _modules}] = Supervisor.which_children(supervisor)
    now = DateTime.from_unix!(1_800_000_500)
    lease = lease!("session_restart", "node_a", "lease_a", 1, DateTime.add(now, 30, :second))

    assert :ok = LeaseRegistry.mirror(registry, lease)
    assert LeaseRegistry.current_fence(registry, "session_restart").holder == "node_a"

    Process.exit(registry, :kill)
    restarted_registry = wait_for_restart(supervisor, registry)

    assert restarted_registry != registry
    assert nil == LeaseRegistry.current_fence(restarted_registry, "session_restart")
  end

  test "lease registry serializes concurrent acquisition attempts", %{registry: registry} do
    now = DateTime.from_unix!(1_800_000_500)

    results =
      1..8
      |> Task.async_stream(
        fn index ->
          lease =
            lease!(
              "session_concurrent",
              "node_#{index}",
              "lease_#{index}",
              1,
              DateTime.add(now, 30, :second)
            )

          LeaseRegistry.acquire(registry, lease, now)
        end,
        max_concurrency: 8,
        timeout: 5_000
      )
      |> Enum.map(fn {:ok, result} -> result end)

    assert Enum.count(results, &match?({:ok, :acquired, %Lease{}}, &1)) == 1
    assert Enum.count(results, &match?({:error, {:held_by_other, _fence}}, &1)) == 7
  end

  test "lease registry reads stale mirrors fail closed and explicit expiry clears them", %{
    registry: registry
  } do
    now = DateTime.from_unix!(1_800_000_500)
    lease = lease!("session_stale", "node_a", "lease_a", 1, DateTime.add(now, 1, :second))

    assert {:ok, :acquired, ^lease} = LeaseRegistry.acquire(registry, lease, now)

    assert {:ok, fence, :mirror_fresh} =
             LeaseRegistry.current_fence_with_posture(registry, "session_stale", now)

    assert fence.holder == "node_a"

    later = DateTime.add(now, 5, :second)

    assert {:error, {:mirror_stale, stale_fence}} =
             LeaseRegistry.current_fence_with_posture(registry, "session_stale", later)

    assert stale_fence.lease_id == "lease_a"
    assert {:ok, :expired, ^lease} = LeaseRegistry.expire(registry, "session_stale", later)

    assert {:error, :missing, :missing} =
             LeaseRegistry.current_fence_with_posture(registry, "session_stale", later)
  end

  test "lease registry release requires the matching lease id", %{registry: registry} do
    now = DateTime.from_unix!(1_800_000_500)
    lease = lease!("session_release", "node_a", "lease_a", 1, DateTime.add(now, 30, :second))

    assert :ok = LeaseRegistry.mirror(registry, lease)

    assert {:error, {:lease_mismatch, fence}} =
             LeaseRegistry.release(registry, "session_release", "lease_b")

    assert fence.lease_id == "lease_a"

    assert {:ok, :released, ^lease} =
             LeaseRegistry.release(registry, "session_release", "lease_a")

    assert nil == LeaseRegistry.current_fence(registry, "session_release")
  end

  test "lease registry reloads mirror state from canonical storage", %{registry: registry} do
    __MODULE__.FakeLeaseStore.reset!()
    now = DateTime.from_unix!(1_800_000_500)
    lease = lease!("session_reload", "node_a", "lease_a", 1, DateTime.add(now, 30, :second))

    assert {:ok, :acquired, ^lease} = __MODULE__.FakeLeaseStore.acquire_lease(lease, now, [])

    assert {:ok, ^lease, :canonical} =
             LeaseRegistry.reload_from_store(
               registry,
               __MODULE__.FakeLeaseStore,
               "tenant://runtime/a",
               "session_reload"
             )

    assert LeaseRegistry.current_fence(registry, "session_reload").holder == "node_a"
  end

  test "lease registry emits lifecycle telemetry", %{registry: registry} do
    handler_id = {__MODULE__, self(), :lease_registry_telemetry}

    events = [
      [:outer_brain, :runtime, :lease_registry, :acquire],
      [:outer_brain, :runtime, :lease_registry, :renew],
      [:outer_brain, :runtime, :lease_registry, :expire],
      [:outer_brain, :runtime, :lease_registry, :release]
    ]

    :ok =
      :telemetry.attach_many(
        handler_id,
        events,
        &__MODULE__.handle_lease_registry_telemetry/4,
        self()
      )

    on_exit(fn -> :telemetry.detach(handler_id) end)

    now = DateTime.from_unix!(1_800_000_500)
    lease = lease!("session_telemetry", "node_a", "lease_a", 1, DateTime.add(now, 1, :second))

    release_lease =
      lease!("session_release_telemetry", "node_a", "lease_b", 1, DateTime.add(now, 30, :second))

    assert {:ok, :acquired, ^lease} = LeaseRegistry.acquire(registry, lease, now)
    assert {:ok, :renewed, ^lease} = LeaseRegistry.acquire(registry, lease, now)
    assert :ok = LeaseRegistry.mirror(registry, release_lease)

    assert {:ok, :released, ^release_lease} =
             LeaseRegistry.release(registry, "session_release_telemetry", "lease_b")

    later = DateTime.add(now, 5, :second)
    assert {:ok, :expired, ^lease} = LeaseRegistry.expire(registry, "session_telemetry", later)

    assert_receive {:lease_registry_telemetry,
                    [:outer_brain, :runtime, :lease_registry, :acquire], %{count: 1},
                    %{status: :acquired, session_id: "session_telemetry"}}

    assert_receive {:lease_registry_telemetry, [:outer_brain, :runtime, :lease_registry, :renew],
                    %{count: 1}, %{status: :renewed, session_id: "session_telemetry"}}

    assert_receive {:lease_registry_telemetry,
                    [:outer_brain, :runtime, :lease_registry, :release], %{count: 1},
                    %{status: :released, session_id: "session_release_telemetry"}}

    assert_receive {:lease_registry_telemetry, [:outer_brain, :runtime, :lease_registry, :expire],
                    %{count: 1}, %{status: :expired, session_id: "session_telemetry"}}
  end

  def handle_lease_registry_telemetry(event, measurements, metadata, test_pid) do
    send(test_pid, {:lease_registry_telemetry, event, measurements, metadata})
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

  defp lease!(session_id, holder, lease_id, epoch, expires_at) do
    {:ok, lease} =
      Lease.new(%{
        session_id: session_id,
        holder: holder,
        lease_id: lease_id,
        epoch: epoch,
        expires_at: expires_at
      })

    lease
  end

  defp wait_for_restart(supervisor, old_pid, attempts \\ 20)

  defp wait_for_restart(_supervisor, old_pid, 0),
    do: flunk("registry did not restart from #{inspect(old_pid)}")

  defp wait_for_restart(supervisor, old_pid, attempts) do
    case Supervisor.which_children(supervisor) do
      [{_id, new_pid, _type, _modules}] when is_pid(new_pid) and new_pid != old_pid ->
        new_pid

      _other ->
        Process.sleep(10)
        wait_for_restart(supervisor, old_pid, attempts - 1)
    end
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

    def fetch_current_lease(_tenant_id, session_id, _opts) do
      ensure_table!()

      case :ets.lookup(@table, session_id) do
        [{_session_id, %Lease{} = lease}] -> {:ok, lease}
        [] -> :error
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
