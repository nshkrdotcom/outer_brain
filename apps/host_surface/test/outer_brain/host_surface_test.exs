defmodule OuterBrain.HostSurfaceTest do
  use ExUnit.Case, async: false

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
               ttl_seconds: 30
             )

    assert lease.session_id == "session_alpha"

    assert {:ok, publication, _row} =
             HostSurface.provisional_reply("causal_1", "Working on it")

    assert publication.phase == :provisional
  end
end
