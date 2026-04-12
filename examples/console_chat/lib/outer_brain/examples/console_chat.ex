defmodule OuterBrain.Examples.ConsoleChat do
  @moduledoc """
  Smoke example for a conversational semantic-session entrypoint.
  """

  alias OuterBrain.Bridges.ManifestCompiler
  alias OuterBrain.HostSurface

  @spec run_demo() :: map()
  def run_demo do
    Application.ensure_all_started(:outer_brain_host_surface)

    {:ok, _lease_status, lease} =
      HostSurface.open_session(
        "session_console",
        "console_host",
        now: DateTime.from_unix!(1_800_000_800),
        epoch: 1,
        ttl_seconds: 30
      )

    {:ok, snapshot} =
      ManifestCompiler.compile(
        [
          %{
            name: "reply_to_user",
            description: "Reply to the user",
            input_schema_hash: "schema_reply"
          }
        ],
        manifest_id: "manifest_console",
        version: "1",
        compiled_at: DateTime.from_unix!(1_800_000_801)
      )

    {:ok, publication, _row} = HostSurface.provisional_reply("causal_console", "Working on it")

    %{
      lease_holder: lease.holder,
      manifest_id: snapshot.manifest_id,
      publication_phase: publication.phase
    }
  end
end
