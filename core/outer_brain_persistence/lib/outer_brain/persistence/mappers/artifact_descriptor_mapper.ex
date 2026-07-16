defmodule OuterBrain.Persistence.ArtifactDescriptorMapper do
  @moduledoc false

  alias GroundPlane.Contracts.ArtifactDescriptor

  @spec to_schema_attrs(ArtifactDescriptor.t()) :: map()
  def to_schema_attrs(%ArtifactDescriptor{} = descriptor) do
    descriptor
    |> ArtifactDescriptor.dump()
    |> Map.put(:descriptor_digest, ArtifactDescriptor.digest(descriptor))
  end

  @spec from_schema(struct()) :: ArtifactDescriptor.t()
  def from_schema(schema) do
    ArtifactDescriptor.new!(%{
      artifact_ref: schema.artifact_ref,
      tenant_ref: schema.tenant_ref,
      owner_ref: schema.owner_ref,
      content_digest: schema.content_digest,
      size_bytes: schema.size_bytes,
      media_type: schema.media_type,
      schema_ref: schema.schema_ref,
      schema_version: schema.schema_version,
      classification: schema.classification,
      provenance: schema.provenance,
      causal_parent_refs: schema.causal_parent_refs,
      producing_operation_ref: schema.producing_operation_ref,
      retention: schema.retention,
      deletion_state: schema.deletion_state,
      location_ref: schema.location_ref
    })
  end
end
