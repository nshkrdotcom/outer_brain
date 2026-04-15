defmodule OuterBrain.Persistence.Schemas.RecoveryTask do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:task_id, :string, autogenerate: false}

  schema "recovery_tasks" do
    field(:session_id, :string)
    field(:reason, :string)
    field(:status, Ecto.Enum, values: [:pending, :running, :done])

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:task_id, :session_id, :reason, :status])
    |> validate_required([:task_id, :session_id, :reason, :status])
  end
end
