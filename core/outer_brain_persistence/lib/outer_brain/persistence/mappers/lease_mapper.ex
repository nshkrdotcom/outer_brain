defmodule OuterBrain.Persistence.LeaseMapper do
  @moduledoc false

  alias OuterBrain.Contracts.Lease

  @spec from_schema(struct()) :: Lease.t()
  def from_schema(schema) do
    %Lease{
      session_id: schema.session_id,
      holder: schema.holder,
      lease_id: schema.lease_id,
      epoch: schema.epoch,
      expires_at: schema.expires_at
    }
  end
end
