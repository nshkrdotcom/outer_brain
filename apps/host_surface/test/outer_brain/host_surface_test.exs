defmodule OuterBrain.HostSurfaceTest do
  use ExUnit.Case, async: false

  alias OuterBrain.Contracts.{Fence, Lease}
  alias OuterBrain.HostSurface

  setup do
    Application.ensure_all_started(:outer_brain_host_surface)
    :ok
  end

  test "host surface opens a session and returns a provisional reply shape" do
    assert {:ok, :acquired, lease} =
             HostSurface.open_session(
               "session_alpha",
               "console_host",
               now: DateTime.from_unix!(1_800_000_700),
               epoch: 1,
               ttl_seconds: 30,
               lease_store: __MODULE__.FakeLeaseStore
             )

    assert lease.session_id == "session_alpha"

    assert {:ok, publication, _row} =
             HostSurface.provisional_reply("causal_1", "Working on it")

    assert publication.phase == :provisional
  end

  defmodule FakeLeaseStore do
    @moduledoc false

    @table :outer_brain_host_surface_fake_lease_store

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
  end
end
