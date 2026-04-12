defmodule OuterBrain.Contracts.ReplyPublication do
  @moduledoc """
  Durable reply publication state for semantic output.
  """

  @phases [:provisional, :final]
  @states [:pending, :published, :suppressed]

  defstruct [:publication_id, :causal_unit_id, :phase, :dedupe_key, :state, :body]

  @type phase :: :provisional | :final
  @type state :: :pending | :published | :suppressed

  @type t :: %__MODULE__{
          publication_id: String.t(),
          causal_unit_id: String.t(),
          phase: phase(),
          dedupe_key: String.t(),
          state: state(),
          body: String.t()
        }

  @spec valid_phase?(term()) :: boolean()
  def valid_phase?(phase), do: phase in @phases

  @spec valid_state?(term()) :: boolean()
  def valid_state?(state), do: state in @states

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(%{
        publication_id: publication_id,
        causal_unit_id: causal_unit_id,
        phase: phase,
        dedupe_key: dedupe_key,
        state: state,
        body: body
      })
      when is_binary(publication_id) and is_binary(causal_unit_id) and phase in @phases and
             is_binary(dedupe_key) and state in @states and is_binary(body) do
    {:ok,
     %__MODULE__{
       publication_id: publication_id,
       causal_unit_id: causal_unit_id,
       phase: phase,
       dedupe_key: dedupe_key,
       state: state,
       body: body
     }}
  end

  def new(_attrs), do: {:error, :invalid_reply_publication}
end
