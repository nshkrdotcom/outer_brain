defmodule OuterBrain.Quality.CheckpointTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Quality.{Checkpoint, Critic}

  test "quality checkpoints are replayable and preserve outcome state" do
    assert {:ok, checkpoint} =
             Checkpoint.new(%{
               checkpoint_id: "checkpoint_1",
               stage: :reply_draft,
               outcome: :pass,
               notes: ["looks good"]
             })

    assert checkpoint.outcome == :pass
  end

  test "critic creates clarify and reject checkpoints without private process state" do
    prompt_pack = %{manifest_id: "manifest_1"}

    assert {:ok, %{outcome: :clarify}} =
             Critic.evaluate(prompt_pack, "short", checkpoint_id: "checkpoint_2")

    assert {:ok, %{outcome: :reject, critical: true}} =
             Critic.evaluate(prompt_pack, "This contains forbidden content",
               checkpoint_id: "checkpoint_3"
             )
  end
end
