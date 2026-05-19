defmodule OuterBrain.Persistence.Repo do
  @moduledoc false

  use Ecto.Repo,
    otp_app: :outer_brain_persistence,
    adapter: Ecto.Adapters.Postgres
end
