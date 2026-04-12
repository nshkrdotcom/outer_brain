defmodule OuterBrain.Bridges.IntentEnvelopeTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Bridges.IntentEnvelope
  alias OuterBrain.Contracts.ActionRequest

  test "validated action requests project into structured policy envelopes" do
    assert {:ok, request} =
             ActionRequest.new(%{
               request_id: "request_1",
               session_id: "session_alpha",
               manifest_id: "manifest_1",
               route: "reply_to_user",
               args: %{"body" => "hello"},
               provenance: %{turn_id: "turn_1"}
             })

    assert %{intent_id: "request_1", route: "reply_to_user"} = IntentEnvelope.build(request)
  end
end
