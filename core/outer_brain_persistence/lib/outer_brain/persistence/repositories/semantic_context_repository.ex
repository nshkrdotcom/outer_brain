defmodule OuterBrain.Persistence.SemanticContextRepository do
  @moduledoc false

  import Ecto.Query

  alias GroundPlane.Boundary.Codec
  alias OuterBrain.Contracts.SemanticContextProvenance
  alias OuterBrain.Persistence.{ArtifactDescriptorRepository, SemanticContextMapper}
  alias OuterBrain.Persistence.Schemas.SemanticContext

  @type record :: %{
          provenance: SemanticContextProvenance.t(),
          context_artifact_descriptor: GroundPlane.Contracts.ArtifactDescriptor.t(),
          prompt_artifact_descriptor: GroundPlane.Contracts.ArtifactDescriptor.t(),
          lineage: map()
        }

  @spec record(module(), String.t(), SemanticContextProvenance.t(), map()) ::
          {:ok, SemanticContextProvenance.t()} | {:error, term()}
  def record(repo, tenant_ref, %SemanticContextProvenance{} = provenance, lineage) do
    with :ok <- require_tenant(tenant_ref, provenance),
         :ok <- validate_provenance_refs(provenance.provenance_refs),
         {:ok, lineage} <- validate_lineage(lineage, provenance) do
      case fetch_schema(repo, tenant_ref, provenance.semantic_ref, lock: true) do
        nil -> insert(repo, provenance, lineage)
        schema -> verify_idempotent(schema, provenance, lineage)
      end
    end
  end

  @spec fetch(module(), String.t(), String.t()) :: {:ok, record()} | :error
  def fetch(repo, tenant_ref, semantic_ref) do
    SemanticContext
    |> where(
      [context],
      context.tenant_ref == ^tenant_ref and context.semantic_ref == ^semantic_ref
    )
    |> repo.one()
    |> map_record(repo, tenant_ref)
  end

  @spec search(module(), String.t(), String.t(), pos_integer()) :: [record()]
  def search(repo, tenant_ref, query, limit)
      when is_binary(tenant_ref) and is_binary(query) and is_integer(limit) and limit > 0 do
    normalized_query = String.trim(query)

    if normalized_query == "" or byte_size(normalized_query) > 256 do
      []
    else
      SemanticContext
      |> where([context], context.tenant_ref == ^tenant_ref)
      |> where(
        [context],
        fragment(
          "to_tsvector('simple', ?) @@ websearch_to_tsquery('simple', ?)",
          context.search_document,
          ^normalized_query
        )
      )
      |> order_by([context], desc: context.inserted_at, asc: context.semantic_ref)
      |> limit(^min(limit, 100))
      |> repo.all()
      |> Enum.map(fn context ->
        {:ok, record} = map_record(context, repo, tenant_ref)
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

  defp insert(repo, provenance, lineage) do
    %SemanticContext{}
    |> SemanticContext.changeset(SemanticContextMapper.to_schema_attrs(provenance, lineage))
    |> repo.insert()
    |> case do
      {:ok, _schema} -> {:ok, provenance}
      {:error, changeset} -> {:error, changeset}
    end
  end

  defp verify_idempotent(schema, provenance, lineage) do
    expected_digest =
      Codec.digest(%{
        provenance: SemanticContextProvenance.to_map(provenance),
        lineage: lineage
      })

    if schema.provenance_digest == expected_digest do
      {:ok, SemanticContextMapper.from_schema(schema)}
    else
      {:error, {:semantic_context_conflict, provenance.semantic_ref}}
    end
  end

  defp map_record(nil, _repo, _tenant_ref), do: :error

  defp map_record(context, repo, tenant_ref) do
    with {:ok, context_descriptor} <-
           ArtifactDescriptorRepository.fetch(repo, tenant_ref, context.context_artifact_ref),
         {:ok, prompt_descriptor} <-
           ArtifactDescriptorRepository.fetch(repo, tenant_ref, context.prompt_artifact_ref) do
      {:ok,
       %{
         provenance: SemanticContextMapper.from_schema(context),
         context_artifact_descriptor: context_descriptor,
         prompt_artifact_descriptor: prompt_descriptor,
         lineage: SemanticContextMapper.lineage_from_schema(context)
       }}
    else
      :error -> :error
    end
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

  defp validate_lineage(lineage, provenance) when is_map(lineage) do
    required = ~w(
      run_ref turn_ref context_artifact_ref prompt_artifact_ref model_profile_ref
      memory_snapshot_refs
    )a

    missing =
      Enum.find(required, fn field ->
        value = Map.get(lineage, field)
        if field == :memory_snapshot_refs, do: not is_list(value), else: not present?(value)
      end)

    cond do
      missing ->
        {:error, {:invalid_semantic_lineage, missing}}

      provenance.resource_ref != lineage.turn_ref ->
        {:error, :semantic_turn_ref_mismatch}

      provenance.context_hash == provenance.prompt_hash ->
        {:error, :context_prompt_artifacts_not_distinct}

      true ->
        {:ok, Map.take(lineage, required ++ [:previous_semantic_ref])}
    end
  end

  defp validate_lineage(_lineage, _provenance), do: {:error, :invalid_semantic_lineage}

  defp present?(value), do: is_binary(value) and value != ""
end
