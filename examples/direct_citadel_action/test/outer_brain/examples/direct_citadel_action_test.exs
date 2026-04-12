defmodule OuterBrain.Examples.DirectCitadelActionTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Examples.DirectCitadelAction

  test "direct citadel action example returns a structured envelope" do
    assert %{intent_id: "request_direct", route: "reply_to_user"} =
             DirectCitadelAction.build_envelope()
  end
end
