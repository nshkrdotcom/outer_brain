defmodule OuterBrain.Persistence.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, args) do
    Supervisor.start_link(children(args),
      strategy: :one_for_one,
      name: OuterBrain.Persistence.Supervisor
    )
  end

  @doc false
  @spec children(keyword()) :: [Supervisor.child_spec() | module() | {module(), term()}]
  def children(args) when is_list(args) do
    if Keyword.get(args, :enabled, false) do
      [Keyword.get(args, :repo_child, OuterBrain.Persistence.Repo)]
    else
      []
    end
  end
end
