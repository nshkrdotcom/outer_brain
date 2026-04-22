defmodule OuterBrain.Persistence.Schemas.ReplyPublication do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:publication_id, :string, autogenerate: false}

  schema "reply_publications" do
    field(:causal_unit_id, :string)
    field(:phase, Ecto.Enum, values: [:provisional, :final])
    field(:state, Ecto.Enum, values: [:pending, :published, :suppressed])
    field(:dedupe_key, :string)
    field(:body, :string)
    field(:body_ref, :map)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :publication_id,
      :causal_unit_id,
      :phase,
      :state,
      :dedupe_key,
      :body,
      :body_ref
    ])
    |> validate_required([
      :publication_id,
      :causal_unit_id,
      :phase,
      :state,
      :dedupe_key,
      :body,
      :body_ref
    ])
    |> unique_constraint(:dedupe_key)
  end
end
