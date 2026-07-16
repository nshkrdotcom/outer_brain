defmodule OuterBrain.Persistence.SemanticContextMapper do
  @moduledoc false

  alias GroundPlane.Boundary.Codec
  alias OuterBrain.Contracts.SemanticContextProvenance

  @spec to_schema_attrs(SemanticContextProvenance.t(), String.t()) :: map()
  def to_schema_attrs(%SemanticContextProvenance{} = provenance, artifact_ref) do
    attrs = SemanticContextProvenance.to_map(provenance)

    attrs
    |> Map.put(:artifact_ref, artifact_ref)
    |> Map.put(:provenance_digest, Codec.digest(attrs))
    |> Map.put(:search_document, search_document(provenance, artifact_ref))
  end

  @spec from_schema(struct()) :: SemanticContextProvenance.t()
  def from_schema(schema) do
    {:ok, provenance} =
      SemanticContextProvenance.new(%{
        tenant_ref: schema.tenant_ref,
        installation_ref: schema.installation_ref,
        workspace_ref: schema.workspace_ref,
        project_ref: schema.project_ref,
        environment_ref: schema.environment_ref,
        resource_ref: schema.resource_ref,
        authority_packet_ref: schema.authority_packet_ref,
        permission_decision_ref: schema.permission_decision_ref,
        idempotency_key: schema.idempotency_key,
        trace_id: schema.trace_id,
        correlation_id: schema.correlation_id,
        release_manifest_ref: schema.release_manifest_ref,
        principal_ref: schema.principal_ref,
        system_actor_ref: schema.system_actor_ref,
        semantic_ref: schema.semantic_ref,
        provider_ref: schema.provider_ref,
        model_ref: schema.model_ref,
        prompt_hash: schema.prompt_hash,
        context_hash: schema.context_hash,
        input_claim_check_ref: schema.input_claim_check_ref,
        output_claim_check_ref: schema.output_claim_check_ref,
        provenance_refs: schema.provenance_refs,
        normalizer_version: schema.normalizer_version,
        redaction_policy_ref: schema.redaction_policy_ref
      })

    provenance
  end

  defp search_document(provenance, artifact_ref) do
    [
      provenance.semantic_ref,
      provenance.provider_ref,
      provenance.model_ref,
      artifact_ref
      | provenance.provenance_refs
    ]
    |> Enum.join(" ")
  end
end
