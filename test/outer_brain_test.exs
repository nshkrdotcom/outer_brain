defmodule OuterBrainTest do
  use ExUnit.Case
  doctest OuterBrain

  test "hello/0 returns the starter marker" do
    assert OuterBrain.hello() == :world
  end
end
