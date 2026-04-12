defmodule OuterBrain.Examples.DirectCitadelAction do
  @moduledoc """
  Smoke example that compiles a validated action request into a policy envelope.
  """

  alias OuterBrain.Bridges.{IntentEnvelope, ManifestCompiler}
  alias OuterBrain.Core.{ActionRequestCompiler, SemanticFrame}

  @spec build_envelope() :: map()
  def build_envelope do
    frame = SemanticFrame.seed("session_direct", "reply to the user")

    {:ok, snapshot} =
      ManifestCompiler.compile(
        [
          %{
            name: "reply_to_user",
            description: "Reply to the user",
            input_schema_hash: "schema_reply"
          }
        ],
        manifest_id: "manifest_direct",
        version: "1",
        compiled_at: DateTime.from_unix!(1_800_000_900)
      )

    {:ok, request} =
      ActionRequestCompiler.compile(
        frame,
        snapshot,
        %{
          request_id: "request_direct",
          manifest_id: "manifest_direct",
          schema_hash: snapshot.schema_hash,
          route: "reply_to_user",
          args: %{"tone" => "brief"},
          provenance: %{turn_id: "turn_direct"}
        },
        0.9
      )

    IntentEnvelope.build(request)
  end
end
