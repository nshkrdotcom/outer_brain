defmodule OuterBrain.Persistence.Application do
  @moduledoc """
  Canonical durable persistence composition for an OuterBrain production host.

  The persistence package is a library application so deterministic test
  fixtures can start an isolated repository. A production host must place this
  child specification in its supervision tree. Missing and memory profiles are
  rejected before a repository child can be returned.
  """

  use Application

  alias OuterBrain.Persistence.DurableSupervisor

  @impl true
  def start(_type, args), do: DurableSupervisor.start_link(args)

  @doc false
  @spec children(keyword()) :: [Supervisor.child_spec() | module() | {module(), term()}]
  def children(args) when is_list(args), do: DurableSupervisor.children(args)
end
