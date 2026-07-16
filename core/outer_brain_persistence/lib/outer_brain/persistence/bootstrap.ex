defmodule OuterBrain.Persistence.Bootstrap do
  @moduledoc false

  use GenServer

  alias OuterBrain.Persistence.ProfilePolicy

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts)

  @impl true
  def init(opts) do
    case ProfilePolicy.preflight(opts) do
      :ok -> {:ok, %{repo: Keyword.fetch!(opts, :repo)}}
      {:error, reason} -> {:stop, {:outer_brain_durable_repository_unavailable, reason}}
    end
  end
end
