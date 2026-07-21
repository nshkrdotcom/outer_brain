defmodule OuterBrain.Persistence.Schemas.ReplyPublication do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:publication_id, :string, autogenerate: false}

  schema "reply_publications" do
    field(:tenant_id, :string)
    field(:causal_unit_id, :string)
    field(:phase, Ecto.Enum, values: [:provisional, :final])
    field(:state, Ecto.Enum, values: [:pending, :published, :suppressed])
    field(:dedupe_key, :string)
    field(:body, :string)
    field(:body_ref, :map)
    field(:run_ref, :string)
    field(:turn_ref, :string)
    field(:attempt_ref, :string)
    field(:reply_artifact_ref, :string)
    field(:next_semantic_ref, :string)

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, [
      :publication_id,
      :tenant_id,
      :causal_unit_id,
      :phase,
      :state,
      :dedupe_key,
      :body,
      :body_ref,
      :run_ref,
      :turn_ref,
      :attempt_ref,
      :reply_artifact_ref,
      :next_semantic_ref
    ])
    |> validate_required([
      :publication_id,
      :tenant_id,
      :causal_unit_id,
      :phase,
      :state,
      :dedupe_key,
      :body,
      :body_ref,
      :run_ref,
      :turn_ref,
      :attempt_ref,
      :reply_artifact_ref,
      :next_semantic_ref
    ])
    |> unique_constraint([:tenant_id, :dedupe_key])
  end
end
