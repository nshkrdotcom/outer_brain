defmodule OuterBrain.Persistence.DurableSupervisor do
  @moduledoc """
  Fail-closed production composition for the canonical PostgreSQL repository.

  The repository starts first. The bootstrap child then verifies the live
  schema and every local migration before the supervisor can finish starting.
  """

  use Supervisor

  alias OuterBrain.Persistence.{Bootstrap, ProfilePolicy, Repo}

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts) when is_list(opts) do
    :ok = ProfilePolicy.require_durable_profile(opts)

    case Keyword.get(opts, :name, __MODULE__) do
      nil -> Supervisor.start_link(__MODULE__, opts)
      name -> Supervisor.start_link(__MODULE__, opts, name: name)
    end
  end

  @impl true
  def init(opts), do: Supervisor.init(children(opts), strategy: :one_for_all)

  @doc false
  @spec children(keyword()) :: [Supervisor.child_spec() | {module(), keyword()}]
  def children(opts) do
    :ok = ProfilePolicy.require_durable_profile(opts)

    bootstrap = {Bootstrap, profile: :durable_redacted, repo: Repo}

    case Keyword.get(opts, :repo_mode, :owned) do
      :owned -> [{Repo, Keyword.get(opts, :repo_options, [])}, bootstrap]
      :external -> [bootstrap]
      mode -> raise ArgumentError, "unsupported OuterBrain Repo mode: #{inspect(mode)}"
    end
  end
end
