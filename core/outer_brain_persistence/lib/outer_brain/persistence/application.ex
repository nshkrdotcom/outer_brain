defmodule OuterBrain.Persistence.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children =
      if Application.get_env(:outer_brain_persistence, :enabled, false) do
        [OuterBrain.Persistence.Repo]
      else
        []
      end

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: OuterBrain.Persistence.Supervisor
    )
  end
end
