defmodule OuterBrain.Contracts.Fence do
  @moduledoc """
  Fence view projected from a lease.
  """

  alias OuterBrain.Contracts.Lease

  defstruct [:session_id, :holder, :lease_id, :epoch]

  @type t :: %__MODULE__{
          session_id: String.t(),
          holder: String.t(),
          lease_id: String.t(),
          epoch: non_neg_integer()
        }

  @spec from_lease(Lease.t()) :: t()
  def from_lease(%Lease{} = lease) do
    %__MODULE__{
      session_id: lease.session_id,
      holder: lease.holder,
      lease_id: lease.lease_id,
      epoch: lease.epoch
    }
  end

  @spec newer_than?(t(), t()) :: boolean()
  def newer_than?(%__MODULE__{epoch: left}, %__MODULE__{epoch: right}) do
    left > right
  end
end
