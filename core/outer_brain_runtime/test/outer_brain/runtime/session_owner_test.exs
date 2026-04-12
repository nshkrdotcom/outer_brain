defmodule OuterBrain.Runtime.SessionOwnerTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Runtime.{LeaseRegistry, SessionOwner, StreamState, WakeCoordinator}

  setup do
    registry = start_supervised!({LeaseRegistry, name: nil})
    %{registry: registry}
  end

  test "one semantic session has exactly one live owner per fence epoch", %{registry: registry} do
    now = DateTime.from_unix!(1_800_000_500)

    assert {:ok, :acquired, lease} =
             SessionOwner.acquire(registry, "session_alpha", "node_a", 1, now, ttl_seconds: 30)

    assert {:error, {:held_by_other, fence}} =
             SessionOwner.acquire(registry, "session_alpha", "node_b", 1, now, ttl_seconds: 30)

    assert fence.epoch == 1
    assert fence.holder == "node_a"
    assert lease.epoch == 1
  end

  test "stale owners can be replaced only after expiry and with a newer epoch", %{
    registry: registry
  } do
    now = DateTime.from_unix!(1_800_000_500)

    assert {:ok, :acquired, _lease} =
             SessionOwner.acquire(registry, "session_alpha", "node_a", 1, now, ttl_seconds: 1)

    later = DateTime.add(now, 5, :second)

    assert {:error, {:stale_epoch, _fence}} =
             SessionOwner.acquire(registry, "session_alpha", "node_b", 1, later, ttl_seconds: 30)

    assert {:ok, :acquired, replacement} =
             SessionOwner.acquire(registry, "session_alpha", "node_b", 2, later, ttl_seconds: 30)

    assert LeaseRegistry.current_fence(registry, "session_alpha").holder == "node_b"
    assert replacement.epoch == 2
  end

  test "wake coordination chooses one follow-up path and stream state distinguishes phases" do
    assert WakeCoordinator.next_follow_up(%{wake_path: :re_deliberate}) == :re_deliberate

    stream_state =
      "session_alpha"
      |> StreamState.provisional("publication_1")
      |> StreamState.finalize("publication_2")

    assert stream_state.phase == :final
    assert stream_state.last_publication_id == "publication_2"
  end
end
