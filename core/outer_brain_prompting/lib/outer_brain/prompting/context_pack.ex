defmodule OuterBrain.Prompting.ContextPack do
  @moduledoc """
  Builds a replayable context pack from semantic state and durable references.
  """

  alias OuterBrain.Core.SemanticFrame

  @spec build(SemanticFrame.t(), [String.t()], keyword()) :: map()
  def build(%SemanticFrame{} = frame, refs, opts \\ []) when is_list(refs) do
    %{
      session_id: frame.session_id,
      objective: frame.objective,
      unresolved_questions: frame.unresolved_questions,
      commitments: frame.commitments,
      refs: Enum.uniq(refs),
      mode: Keyword.get(opts, :mode, :reply)
    }
  end
end
