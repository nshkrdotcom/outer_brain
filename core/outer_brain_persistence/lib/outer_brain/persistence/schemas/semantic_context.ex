defmodule OuterBrain.Persistence.Schemas.SemanticContext do
  @moduledoc false

  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:semantic_ref, :string, autogenerate: false}

  schema "outer_brain_semantic_contexts" do
    field(:tenant_ref, :string)
    field(:installation_ref, :string)
    field(:workspace_ref, :string)
    field(:project_ref, :string)
    field(:environment_ref, :string)
    field(:resource_ref, :string)
    field(:authority_packet_ref, :string)
    field(:permission_decision_ref, :string)
    field(:idempotency_key, :string)
    field(:trace_id, :string)
    field(:correlation_id, :string)
    field(:release_manifest_ref, :string)
    field(:principal_ref, :string)
    field(:system_actor_ref, :string)
    field(:provider_ref, :string)
    field(:model_ref, :string)
    field(:prompt_hash, :string)
    field(:context_hash, :string)
    field(:input_claim_check_ref, :string)
    field(:output_claim_check_ref, :string)
    field(:provenance_refs, {:array, :string})
    field(:normalizer_version, :string)
    field(:redaction_policy_ref, :string)
    field(:artifact_ref, :string)
    field(:provenance_digest, :string)
    field(:search_document, :string)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @optional_fields [:principal_ref, :system_actor_ref]
  @fields ~w(
    semantic_ref tenant_ref installation_ref workspace_ref project_ref environment_ref
    resource_ref authority_packet_ref permission_decision_ref idempotency_key trace_id
    correlation_id release_manifest_ref principal_ref system_actor_ref provider_ref model_ref
    prompt_hash context_hash input_claim_check_ref output_claim_check_ref provenance_refs
    normalizer_version redaction_policy_ref artifact_ref provenance_digest search_document
  )a

  def changeset(schema, attrs) do
    schema
    |> cast(attrs, @fields)
    |> validate_required(@fields -- @optional_fields)
    |> validate_actor()
    |> unique_constraint(:semantic_ref)
    |> unique_constraint([:tenant_ref, :idempotency_key])
  end

  defp validate_actor(changeset) do
    if get_field(changeset, :principal_ref) || get_field(changeset, :system_actor_ref) do
      changeset
    else
      add_error(changeset, :principal_ref, "principal_ref or system_actor_ref is required")
    end
  end
end
