defmodule OuterBrain.Bridges.ManifestCompiler do
  @moduledoc """
  Compiles a route catalog into a durable manifest snapshot.
  """

  alias Citadel.DomainSurface, as: Domain
  alias OuterBrain.Contracts.ToolManifestSnapshot

  @spec compile([map()], keyword()) :: {:ok, ToolManifestSnapshot.t()} | {:error, term()}
  def compile(route_catalog, opts \\ []) when is_list(route_catalog) do
    routes =
      Map.new(route_catalog, fn route ->
        route_name = Map.fetch!(route, :name)

        route_metadata =
          route
          |> Map.drop([:name])
          |> Map.put(:description, Map.fetch!(route, :description))
          |> Map.put(:input_schema_hash, Map.fetch!(route, :input_schema_hash))
          |> Map.put_new(:examples, Map.get(route, :examples, []))

        {route_name, route_metadata}
      end)

    ToolManifestSnapshot.new(%{
      manifest_id: Keyword.get(opts, :manifest_id, "manifest_default"),
      version: Keyword.get(opts, :version, "1"),
      schema_hash: Keyword.get(opts, :schema_hash, schema_hash(route_catalog)),
      compiled_at: Keyword.get(opts, :compiled_at, DateTime.utc_now()),
      routes: routes
    })
  end

  @spec compile_domain_routes([module()], keyword()) ::
          {:ok, ToolManifestSnapshot.t()} | {:error, term()}
  def compile_domain_routes(route_sources, opts \\ []) when is_list(route_sources) do
    with {:ok, entries} <- Domain.tool_manifest(route_sources) do
      compile(
        Enum.map(entries, &domain_tool_manifest_entry/1),
        Keyword.put_new(opts, :manifest_id, "manifest_domain")
      )
    end
  end

  defp schema_hash(route_catalog) do
    route_catalog
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end

  defp domain_tool_manifest_entry(entry) do
    %{
      name: Atom.to_string(entry.route_name),
      route_atom: entry.route_name,
      description: entry.description || Atom.to_string(entry.route_name),
      input_schema_hash: entry.schema_hash,
      examples: Map.get(entry.tool_manifest, :examples, []),
      request_type: entry.request_type,
      dispatch_via: entry.dispatch_via,
      semantic_metadata: entry.semantic_metadata,
      tool_manifest: entry.tool_manifest
    }
  end
end
