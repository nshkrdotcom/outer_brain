defmodule OuterBrain.HostSurface.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {OuterBrain.Runtime.LeaseRegistry, name: OuterBrain.Runtime.LeaseRegistry}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end
