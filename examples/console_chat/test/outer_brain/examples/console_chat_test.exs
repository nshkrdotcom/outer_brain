defmodule OuterBrain.Examples.ConsoleChatTest do
  use ExUnit.Case, async: false

  alias OuterBrain.Examples.ConsoleChat

  test "console chat example proves the semantic-session happy path" do
    assert %{
             lease_holder: "console_host",
             manifest_id: "manifest_console",
             publication_phase: :provisional
           } =
             ConsoleChat.run_demo()
  end
end
