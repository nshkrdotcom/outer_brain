defmodule OuterBrain.Runtime.StreamState do
  @moduledoc """
  Minimal stream-state helper that distinguishes provisional and final phases.
  """

  defstruct [:session_id, :phase, :last_publication_id]

  @type t :: %__MODULE__{
          session_id: String.t(),
          phase: :provisional | :final,
          last_publication_id: String.t() | nil
        }

  @spec provisional(String.t(), String.t()) :: t()
  def provisional(session_id, publication_id) do
    %__MODULE__{session_id: session_id, phase: :provisional, last_publication_id: publication_id}
  end

  @spec finalize(t(), String.t()) :: t()
  def finalize(%__MODULE__{session_id: session_id}, publication_id) do
    %__MODULE__{session_id: session_id, phase: :final, last_publication_id: publication_id}
  end
end
