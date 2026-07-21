defmodule OuterBrain.Persistence.ArtifactPayloadRepository do
  @moduledoc false

  import Ecto.Query

  alias GroundPlane.Boundary.Codec
  alias OuterBrain.Persistence.ArtifactAccess
  alias OuterBrain.Persistence.Schemas.{ArtifactDescriptor, ArtifactPayload}
  alias OuterBrain.Prompting.ImmutableArtifact

  @spec record(module(), String.t(), ImmutableArtifact.t()) ::
          {:ok, ImmutableArtifact.t()} | {:error, term()}
  def record(repo, tenant_ref, %ImmutableArtifact{} = artifact) do
    with :ok <- validate_artifact(tenant_ref, artifact) do
      case fetch_schema(repo, tenant_ref, artifact.descriptor.artifact_ref, lock: true) do
        nil -> insert(repo, tenant_ref, artifact)
        schema -> verify_idempotent(schema, artifact)
      end
    end
  end

  @spec resolve(module(), String.t(), ArtifactAccess.t()) ::
          {:ok, %{descriptor: struct(), payload: binary()}} | {:error, term()}
  def resolve(repo, artifact_ref, %ArtifactAccess{} = access) do
    result =
      ArtifactPayload
      |> join(:inner, [payload], descriptor in ArtifactDescriptor,
        on:
          descriptor.artifact_ref == payload.artifact_ref and
            descriptor.tenant_ref == payload.tenant_ref
      )
      |> where(
        [payload, descriptor],
        payload.tenant_ref == ^access.tenant_ref and payload.artifact_ref == ^artifact_ref and
          descriptor.deletion_state == "active"
      )
      |> select([payload, descriptor], {payload, descriptor})
      |> repo.one()

    case result do
      nil ->
        {:error, :artifact_not_found}

      {payload, descriptor} ->
        resolve_authorized(payload, descriptor, access)
    end
  end

  defp resolve_authorized(payload, descriptor, access) do
    authorized? =
      payload.authority_packet_ref == access.authority_packet_ref and
        access.reader_ref in payload.allowed_reader_refs and
        access.operation_ref in payload.allowed_operation_refs

    cond do
      not authorized? ->
        {:error, :artifact_access_denied}

      payload.content_digest != sha256(payload.payload) ->
        {:error, :artifact_integrity_failed}

      descriptor.content_digest != payload.content_digest ->
        {:error, :artifact_integrity_failed}

      true ->
        {:ok,
         %{
           descriptor: OuterBrain.Persistence.ArtifactDescriptorMapper.from_schema(descriptor),
           payload: payload.payload
         }}
    end
  end

  defp fetch_schema(repo, tenant_ref, artifact_ref, opts) do
    query =
      ArtifactPayload
      |> where(
        [payload],
        payload.tenant_ref == ^tenant_ref and payload.artifact_ref == ^artifact_ref
      )

    query = if Keyword.get(opts, :lock, false), do: lock(query, "FOR UPDATE"), else: query
    repo.one(query)
  end

  defp insert(repo, tenant_ref, artifact) do
    attrs = schema_attrs(tenant_ref, artifact)

    %ArtifactPayload{}
    |> ArtifactPayload.changeset(attrs)
    |> repo.insert()
    |> case do
      {:ok, _schema} -> {:ok, artifact}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp verify_idempotent(schema, artifact) do
    expected = schema_attrs(schema.tenant_ref, artifact)

    if schema.record_digest == expected.record_digest do
      {:ok, artifact}
    else
      {:error, {:artifact_payload_conflict, artifact.descriptor.artifact_ref}}
    end
  end

  defp validate_artifact(tenant_ref, artifact) do
    descriptor = artifact.descriptor

    cond do
      descriptor.tenant_ref != tenant_ref ->
        {:error, :artifact_payload_tenant_mismatch}

      descriptor.content_digest != sha256(artifact.payload) ->
        {:error, :artifact_payload_digest_mismatch}

      descriptor.size_bytes != byte_size(artifact.payload) ->
        {:error, :artifact_payload_size_mismatch}

      descriptor.location_ref == nil ->
        {:error, :artifact_payload_location_missing}

      true ->
        :ok
    end
  end

  defp schema_attrs(tenant_ref, artifact) do
    attrs = %{
      artifact_ref: artifact.descriptor.artifact_ref,
      tenant_ref: tenant_ref,
      content_digest: artifact.descriptor.content_digest,
      media_type: artifact.descriptor.media_type,
      payload: artifact.payload,
      authority_packet_ref: artifact.authority_packet_ref,
      allowed_reader_refs: artifact.allowed_reader_refs,
      allowed_operation_refs: artifact.allowed_operation_refs
    }

    Map.put(attrs, :record_digest, Codec.digest(Map.delete(attrs, :payload)))
  end

  defp sha256(payload),
    do: "sha256:" <> Base.encode16(:crypto.hash(:sha256, payload), case: :lower)
end
