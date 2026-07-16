defmodule OuterBrain.Persistence.SemanticContextRepository do
  @moduledoc false

  import Ecto.Query

  alias GroundPlane.Boundary.Codec
  alias OuterBrain.Contracts.SemanticContextProvenance
  alias OuterBrain.Persistence.ArtifactDescriptorMapper
  alias OuterBrain.Persistence.Schemas.{ArtifactDescriptor, SemanticContext}
  alias OuterBrain.Persistence.SemanticContextMapper

  @type record :: %{
          provenance: SemanticContextProvenance.t(),
          artifact_descriptor: GroundPlane.Contracts.ArtifactDescriptor.t()
        }

  @spec record(module(), String.t(), SemanticContextProvenance.t(), String.t()) ::
          {:ok, SemanticContextProvenance.t()} | {:error, term()}
  def record(repo, tenant_ref, %SemanticContextProvenance{} = provenance, artifact_ref) do
    with :ok <- require_tenant(tenant_ref, provenance),
         :ok <- validate_provenance_refs(provenance.provenance_refs) do
      case fetch_schema(repo, tenant_ref, provenance.semantic_ref, lock: true) do
        nil -> insert(repo, provenance, artifact_ref)
        schema -> verify_idempotent(schema, provenance, artifact_ref)
      end
    end
  end

  @spec fetch(module(), String.t(), String.t()) :: {:ok, record()} | :error
  def fetch(repo, tenant_ref, semantic_ref) do
    SemanticContext
    |> join(:inner, [context], artifact in ArtifactDescriptor,
      on:
        artifact.tenant_ref == context.tenant_ref and
          artifact.artifact_ref == context.artifact_ref
    )
    |> where(
      [context, _artifact],
      context.tenant_ref == ^tenant_ref and context.semantic_ref == ^semantic_ref
    )
    |> select([context, artifact], {context, artifact})
    |> repo.one()
    |> map_pair()
  end

  @spec search(module(), String.t(), String.t(), pos_integer()) :: [record()]
  def search(repo, tenant_ref, query, limit)
      when is_binary(tenant_ref) and is_binary(query) and is_integer(limit) and limit > 0 do
    normalized_query = String.trim(query)

    if normalized_query == "" or byte_size(normalized_query) > 256 do
      []
    else
      SemanticContext
      |> join(:inner, [context], artifact in ArtifactDescriptor,
        on:
          artifact.tenant_ref == context.tenant_ref and
            artifact.artifact_ref == context.artifact_ref
      )
      |> where([context, _artifact], context.tenant_ref == ^tenant_ref)
      |> where(
        [context, _artifact],
        fragment(
          "to_tsvector('simple', ?) @@ websearch_to_tsquery('simple', ?)",
          context.search_document,
          ^normalized_query
        )
      )
      |> order_by([context, _artifact], desc: context.inserted_at, asc: context.semantic_ref)
      |> limit(^min(limit, 100))
      |> select([context, artifact], {context, artifact})
      |> repo.all()
      |> Enum.map(fn pair ->
        {:ok, record} = map_pair(pair)
        record
      end)
    end
  end

  defp fetch_schema(repo, tenant_ref, semantic_ref, opts) do
    query =
      SemanticContext
      |> where(
        [context],
        context.tenant_ref == ^tenant_ref and context.semantic_ref == ^semantic_ref
      )

    query = if Keyword.get(opts, :lock, false), do: lock(query, "FOR UPDATE"), else: query
    repo.one(query)
  end

  defp insert(repo, provenance, artifact_ref) do
    %SemanticContext{}
    |> SemanticContext.changeset(SemanticContextMapper.to_schema_attrs(provenance, artifact_ref))
    |> repo.insert()
    |> case do
      {:ok, _schema} -> {:ok, provenance}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp verify_idempotent(schema, provenance, artifact_ref) do
    expected_digest = provenance |> SemanticContextProvenance.to_map() |> Codec.digest()

    if schema.provenance_digest == expected_digest and schema.artifact_ref == artifact_ref do
      {:ok, SemanticContextMapper.from_schema(schema)}
    else
      {:error, {:semantic_context_conflict, provenance.semantic_ref}}
    end
  end

  defp map_pair(nil), do: :error

  defp map_pair({context, artifact}) do
    {:ok,
     %{
       provenance: SemanticContextMapper.from_schema(context),
       artifact_descriptor: ArtifactDescriptorMapper.from_schema(artifact)
     }}
  end

  defp require_tenant(tenant_ref, %SemanticContextProvenance{tenant_ref: tenant_ref}), do: :ok

  defp require_tenant(tenant_ref, %SemanticContextProvenance{tenant_ref: context_tenant}) do
    {:error, {:semantic_context_tenant_mismatch, tenant_ref, context_tenant}}
  end

  defp validate_provenance_refs(refs) when is_list(refs) do
    if Enum.all?(refs, &(is_binary(&1) and String.trim(&1) != "" and byte_size(&1) <= 2_048)) do
      :ok
    else
      {:error, :invalid_semantic_provenance_refs}
    end
  end

  defp validate_provenance_refs(_refs), do: {:error, :invalid_semantic_provenance_refs}
end
