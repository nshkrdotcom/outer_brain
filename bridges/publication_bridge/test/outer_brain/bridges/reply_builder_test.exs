defmodule OuterBrain.Bridges.ReplyBuilderTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Bridges.ReplyBuilder

  test "provisional and final reply publications stay distinct" do
    assert {:ok, provisional, provisional_row} =
             ReplyBuilder.provisional("causal_1", "Working on it", "causal_1:provisional")

    assert {:ok, final, final_row} =
             ReplyBuilder.final("causal_1", "Done", "causal_1:final")

    assert provisional.phase == :provisional
    assert final.phase == :final
    assert provisional_row.phase == :provisional
    assert final_row.phase == :final
  end
end
