defmodule OuterBrain.Bridges.ManifestCompiler do
  @moduledoc """
  Compiles a route catalog into a durable manifest snapshot.
  """

  alias OuterBrain.Contracts.ToolManifestSnapshot

  @spec compile([map()], keyword()) :: {:ok, ToolManifestSnapshot.t()} | {:error, term()}
  def compile(route_catalog, opts \\ []) when is_list(route_catalog) do
    routes =
      Map.new(route_catalog, fn route ->
        {Map.fetch!(route, :name),
         %{
           description: Map.fetch!(route, :description),
           input_schema_hash: Map.fetch!(route, :input_schema_hash),
           examples: Map.get(route, :examples, [])
         }}
      end)

    ToolManifestSnapshot.new(%{
      manifest_id: Keyword.get(opts, :manifest_id, "manifest_default"),
      version: Keyword.get(opts, :version, "1"),
      schema_hash: Keyword.get(opts, :schema_hash, schema_hash(route_catalog)),
      compiled_at: Keyword.get(opts, :compiled_at, DateTime.utc_now()),
      routes: routes
    })
  end

  defp schema_hash(route_catalog) do
    route_catalog
    |> :erlang.term_to_binary()
    |> then(&:crypto.hash(:sha256, &1))
    |> Base.encode16(case: :lower)
  end
end
