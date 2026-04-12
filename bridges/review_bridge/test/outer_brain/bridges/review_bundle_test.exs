defmodule OuterBrain.Bridges.ReviewBundleTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Bridges.ReviewBundle
  alias OuterBrain.Quality.Checkpoint

  test "quality checkpoints project into review bundles" do
    assert {:ok, checkpoint} =
             Checkpoint.new(%{
               checkpoint_id: "checkpoint_1",
               stage: :reply_draft,
               outcome: :clarify,
               notes: ["Need more specificity"]
             })

    assert %{outcome: :clarify, critical: false} = ReviewBundle.build(checkpoint)
  end
end
