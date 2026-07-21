defmodule OuterBrain.Persistence.Schemas.ArtifactPayload do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:artifact_ref, :string, autogenerate: false}

  schema "outer_brain_artifact_payloads" do
    field(:tenant_ref, :string)
    field(:content_digest, :string)
    field(:media_type, :string)
    field(:payload, :binary)
    field(:authority_packet_ref, :string)
    field(:allowed_reader_refs, {:array, :string})
    field(:allowed_operation_refs, {:array, :string})
    field(:record_digest, :string)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @fields ~w(
    artifact_ref tenant_ref content_digest media_type payload authority_packet_ref
    allowed_reader_refs allowed_operation_refs record_digest
  )a

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, @fields)
    |> validate_required(@fields)
    |> validate_length(:allowed_reader_refs, min: 1)
    |> validate_length(:allowed_operation_refs, min: 1)
    |> unique_constraint(:artifact_ref)
  end
end
