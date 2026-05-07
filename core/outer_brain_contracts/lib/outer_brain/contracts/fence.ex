defmodule OuterBrain.Contracts.Fence do
  @moduledoc """
  Fence view projected from a lease.
  """

  alias OuterBrain.Contracts.{Lease, PersistencePosture}

  defstruct [
    :session_id,
    :holder,
    :lease_id,
    :epoch,
    persistence_posture: PersistencePosture.memory(:semantic_session)
  ]

  @type t :: %__MODULE__{
          session_id: String.t(),
          holder: String.t(),
          lease_id: String.t(),
          epoch: non_neg_integer(),
          persistence_posture: PersistencePosture.t()
        }

  @spec from_lease(Lease.t()) :: t()
  def from_lease(%Lease{} = lease) do
    %__MODULE__{
      session_id: lease.session_id,
      holder: lease.holder,
      lease_id: lease.lease_id,
      epoch: lease.epoch,
      persistence_posture: lease.persistence_posture
    }
  end

  @spec newer_than?(t(), t()) :: boolean()
  def newer_than?(%__MODULE__{epoch: left}, %__MODULE__{epoch: right}) do
    left > right
  end
end
