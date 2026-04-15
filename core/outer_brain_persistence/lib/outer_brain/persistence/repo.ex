defmodule OuterBrain.Persistence.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :outer_brain_persistence,
    adapter: Ecto.Adapters.Postgres

  @impl true
  def init(_type, config) do
    runtime_config = Application.get_env(:outer_brain_persistence, __MODULE__, [])
    {:ok, Keyword.merge(config, runtime_config)}
  end
end
