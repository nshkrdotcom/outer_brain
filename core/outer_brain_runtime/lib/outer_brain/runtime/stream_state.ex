defmodule OuterBrain.Runtime.StreamState do
  @moduledoc """
  Minimal stream-state helper that distinguishes provisional and final phases.
  """

  alias OuterBrain.Contracts.PersistencePosture

  defstruct [
    :session_id,
    :phase,
    :last_publication_id,
    persistence_posture: PersistencePosture.memory(:publication_state)
  ]

  @type t :: %__MODULE__{
          session_id: String.t(),
          phase: :provisional | :final,
          last_publication_id: String.t() | nil,
          persistence_posture: PersistencePosture.t()
        }

  @spec provisional(String.t(), String.t(), keyword()) :: t()
  def provisional(session_id, publication_id, opts \\ []) do
    %__MODULE__{
      session_id: session_id,
      phase: :provisional,
      last_publication_id: publication_id,
      persistence_posture: PersistencePosture.resolve(:publication_state, opts)
    }
  end

  @spec finalize(t(), String.t()) :: t()
  def finalize(%__MODULE__{session_id: session_id, persistence_posture: posture}, publication_id) do
    %__MODULE__{
      session_id: session_id,
      phase: :final,
      last_publication_id: publication_id,
      persistence_posture: posture
    }
  end
end
