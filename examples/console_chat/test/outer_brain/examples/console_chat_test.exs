defmodule OuterBrain.Examples.ConsoleChatTest do
  use ExUnit.Case, async: false

  alias OuterBrain.Contracts.{Fence, Lease}
  alias OuterBrain.Examples.ConsoleChat

  test "console chat example proves the semantic-session happy path" do
    assert %{
             lease_holder: "console_host",
             manifest_id: "manifest_console",
             publication_phase: :provisional
           } =
             ConsoleChat.run_demo(lease_store: __MODULE__.FakeLeaseStore)
  end

  defmodule FakeLeaseStore do
    @moduledoc false

    @table :outer_brain_console_chat_fake_lease_store

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
