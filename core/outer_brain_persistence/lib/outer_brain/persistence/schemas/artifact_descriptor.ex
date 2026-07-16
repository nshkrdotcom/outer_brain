defmodule OuterBrain.Persistence.Schemas.ArtifactDescriptor do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:artifact_ref, :string, autogenerate: false}

  schema "outer_brain_artifact_descriptors" do
    field(:tenant_ref, :string)
    field(:owner_ref, :string)
    field(:content_digest, :string)
    field(:size_bytes, :integer)
    field(:media_type, :string)
    field(:schema_ref, :string)
    field(:schema_version, :integer)
    field(:classification, :string)
    field(:provenance, :map)
    field(:causal_parent_refs, {:array, :string})
    field(:producing_operation_ref, :string)
    field(:retention, :map)
    field(:deletion_state, :string)
    field(:location_ref, :string)
    field(:descriptor_digest, :string)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @fields ~w(
    artifact_ref tenant_ref owner_ref content_digest size_bytes media_type schema_ref
    schema_version classification provenance causal_parent_refs producing_operation_ref
    retention deletion_state location_ref descriptor_digest
  )a

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, @fields)
    |> validate_required(@fields -- [:location_ref])
    |> unique_constraint(:artifact_ref)
    |> check_constraint(:size_bytes, name: :artifact_size_non_negative)
    |> check_constraint(:schema_version, name: :artifact_schema_version_positive)
    |> check_constraint(:classification, name: :artifact_classification_valid)
    |> check_constraint(:deletion_state, name: :artifact_deletion_state_valid)
  end
end
