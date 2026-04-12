defmodule OuterBrain.Contracts.LeaseAndFenceTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Contracts.{Fence, Lease}

  test "lease and fence keep semantic-session ownership explicit" do
    expires_at = DateTime.from_unix!(1_800_000_000)

    assert {:ok, lease} =
             Lease.new(%{
               session_id: "session_alpha",
               holder: "node_a",
               lease_id: "lease_a",
               epoch: 3,
               expires_at: expires_at
             })

    refute Lease.expired?(lease, DateTime.from_unix!(1_799_999_990))

    assert fence = Fence.from_lease(lease)
    assert fence.session_id == "session_alpha"
    assert Fence.newer_than?(%Fence{fence | epoch: 4}, fence)
  end
end
