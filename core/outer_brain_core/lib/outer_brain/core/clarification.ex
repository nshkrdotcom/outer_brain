defmodule OuterBrain.Core.Clarification do
  @moduledoc """
  Confidence gate for clarification.
  """

  @spec required?(number(), number()) :: boolean()
  def required?(confidence, threshold \\ 0.6)
      when is_number(confidence) and is_number(threshold) do
    confidence < threshold
  end
end
