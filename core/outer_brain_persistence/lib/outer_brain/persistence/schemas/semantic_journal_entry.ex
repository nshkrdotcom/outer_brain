defmodule OuterBrain.Persistence.Schemas.SemanticJournalEntry do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:entry_id, :string, autogenerate: false}

  schema "semantic_journal_entries" do
    field(:session_id, :string)
    field(:causal_unit_id, :string)
    field(:entry_type, :string)
    field(:payload, :map)
    field(:recorded_at, :utc_datetime_usec)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [:entry_id, :session_id, :causal_unit_id, :entry_type, :payload, :recorded_at])
    |> validate_required([
      :entry_id,
      :session_id,
      :causal_unit_id,
      :entry_type,
      :payload,
      :recorded_at
    ])
  end
end
