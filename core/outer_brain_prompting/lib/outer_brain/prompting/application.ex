defmodule OuterBrain.Prompting.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Task.Supervisor, name: OuterBrain.Prompting.TaskSupervisor}
    ]

    Supervisor.start_link(children,
      strategy: :one_for_one,
      name: OuterBrain.Prompting.Supervisor
    )
  end
end
