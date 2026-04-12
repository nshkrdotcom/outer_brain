defmodule OuterBrain.Core.SemanticFrameTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Core.SemanticFrame

  test "semantic frame reduction keeps objectives, questions, commitments, and wake facts durable" do
    frame =
      "session_alpha"
      |> SemanticFrame.seed("help the user")
      |> SemanticFrame.apply_turn(%{question: "Which workspace?"})
      |> SemanticFrame.record_commitment("I will inspect the repo")
      |> SemanticFrame.wake("fact_1")

    assert frame.objective == "help the user"
    assert frame.unresolved_questions == ["Which workspace?"]
    assert frame.commitments == ["I will inspect the repo"]
    assert frame.last_fact_id == "fact_1"
  end
end
