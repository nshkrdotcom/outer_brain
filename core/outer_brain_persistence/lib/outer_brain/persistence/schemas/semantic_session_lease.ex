defmodule OuterBrain.Persistence.Schemas.SemanticSessionLease do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:row_id, :string, autogenerate: false}

  schema "semantic_session_leases" do
    field(:session_id, :string)
    field(:holder, :string)
    field(:lease_id, :string)
    field(:epoch, :integer)
    field(:expires_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:row_id, :session_id, :holder, :lease_id, :epoch, :expires_at])
    |> validate_required([:row_id, :session_id, :holder, :lease_id, :epoch, :expires_at])
    |> unique_constraint(:session_id)
  end
end
