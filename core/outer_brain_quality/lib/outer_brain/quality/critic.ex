defmodule OuterBrain.Quality.Critic do
  @moduledoc """
  Small semantic critic pass used to prove replayable quality checkpoints.
  """

  alias OuterBrain.Quality.Checkpoint

  @spec evaluate(map(), String.t(), keyword()) :: {:ok, Checkpoint.t()} | {:error, term()}
  def evaluate(prompt_pack, draft, opts \\ []) when is_map(prompt_pack) and is_binary(draft) do
    min_length = Keyword.get(opts, :min_length, 12)

    outcome =
      cond do
        String.length(draft) < min_length -> :clarify
        String.contains?(String.downcase(draft), "forbidden") -> :reject
        true -> :pass
      end

    Checkpoint.new(%{
      checkpoint_id: Keyword.get(opts, :checkpoint_id, "checkpoint_1"),
      stage: Keyword.get(opts, :stage, :reply_draft),
      outcome: outcome,
      notes: ["manifest=#{prompt_pack[:manifest_id] || "unknown"}"],
      critical: outcome == :reject
    })
  end
end
