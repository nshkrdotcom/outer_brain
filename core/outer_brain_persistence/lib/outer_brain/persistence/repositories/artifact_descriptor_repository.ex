defmodule OuterBrain.Persistence.ArtifactDescriptorRepository do
  @moduledoc false

  import Ecto.Query

  alias GroundPlane.Contracts.ArtifactDescriptor
  alias OuterBrain.Persistence.{ArtifactDescriptorMapper, ArtifactMetadataPolicy}
  alias OuterBrain.Persistence.Schemas.ArtifactDescriptor, as: ArtifactDescriptorSchema

  @spec record(module(), String.t(), ArtifactDescriptor.t()) ::
          {:ok, ArtifactDescriptor.t()} | {:error, term()}
  def record(repo, tenant_ref, %ArtifactDescriptor{} = descriptor) do
    with :ok <- require_tenant(tenant_ref, descriptor),
         {:ok, descriptor} <- ArtifactDescriptor.new(descriptor),
         :ok <- ArtifactMetadataPolicy.validate(descriptor) do
      case fetch_schema(repo, tenant_ref, descriptor.artifact_ref, lock: true) do
        nil -> insert(repo, descriptor)
        schema -> verify_idempotent(schema, descriptor)
      end
    end
  end

  @spec fetch(module(), String.t(), String.t()) :: {:ok, ArtifactDescriptor.t()} | :error
  def fetch(repo, tenant_ref, artifact_ref) do
    case fetch_schema(repo, tenant_ref, artifact_ref) do
      nil -> :error
      schema -> {:ok, ArtifactDescriptorMapper.from_schema(schema)}
    end
  end

  defp fetch_schema(repo, tenant_ref, artifact_ref, opts \\ []) do
    query =
      ArtifactDescriptorSchema
      |> where(
        [descriptor],
        descriptor.tenant_ref == ^tenant_ref and descriptor.artifact_ref == ^artifact_ref
      )

    query = if Keyword.get(opts, :lock, false), do: lock(query, "FOR UPDATE"), else: query
    repo.one(query)
  end

  defp insert(repo, descriptor) do
    %ArtifactDescriptorSchema{}
    |> ArtifactDescriptorSchema.changeset(ArtifactDescriptorMapper.to_schema_attrs(descriptor))
    |> repo.insert()
    |> case do
      {:ok, _schema} -> {:ok, descriptor}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp verify_idempotent(schema, descriptor) do
    if schema.descriptor_digest == ArtifactDescriptor.digest(descriptor) do
      {:ok, ArtifactDescriptorMapper.from_schema(schema)}
    else
      {:error, {:artifact_descriptor_conflict, descriptor.artifact_ref}}
    end
  end

  defp require_tenant(tenant_ref, %ArtifactDescriptor{tenant_ref: tenant_ref}), do: :ok

  defp require_tenant(tenant_ref, %ArtifactDescriptor{tenant_ref: descriptor_tenant}) do
    {:error, {:artifact_tenant_mismatch, tenant_ref, descriptor_tenant}}
  end
end
