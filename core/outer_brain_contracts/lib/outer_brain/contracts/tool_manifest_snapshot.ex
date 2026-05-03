defmodule OuterBrain.Contracts.ToolManifestSnapshot do
  @moduledoc """
  Durable snapshot of the tool manifest presented to a model turn.
  """

  defstruct [:manifest_id, :version, :schema_hash, :compiled_at, routes: %{}]

  @type route_metadata :: %{
          required(:description) => String.t(),
          required(:input_schema_hash) => String.t(),
          optional(:route_atom) => atom(),
          optional(:examples) => [map()]
        }

  @type t :: %__MODULE__{
          manifest_id: String.t(),
          version: String.t(),
          schema_hash: String.t(),
          compiled_at: DateTime.t(),
          routes: %{optional(String.t()) => route_metadata()}
        }

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(%{
        manifest_id: manifest_id,
        version: version,
        schema_hash: schema_hash,
        compiled_at: %DateTime{} = compiled_at,
        routes: routes
      })
      when is_binary(manifest_id) and is_binary(version) and is_binary(schema_hash) and
             is_map(routes) do
    if Enum.all?(routes, &valid_route?/1) do
      {:ok,
       %__MODULE__{
         manifest_id: manifest_id,
         version: version,
         schema_hash: schema_hash,
         compiled_at: compiled_at,
         routes: routes
       }}
    else
      {:error, :invalid_routes}
    end
  end

  def new(_attrs), do: {:error, :invalid_snapshot}

  @spec route_names(t()) :: [String.t()]
  def route_names(%__MODULE__{routes: routes}) do
    routes |> Map.keys() |> Enum.sort()
  end

  @spec selection_valid?(t(), map()) :: :ok | {:error, term()}
  def selection_valid?(
        %__MODULE__{manifest_id: manifest_id, schema_hash: schema_hash, routes: routes},
        %{manifest_id: manifest_id, schema_hash: schema_hash, route: route}
      )
      when is_binary(route) do
    if Map.has_key?(routes, route) do
      :ok
    else
      {:error, :route_not_present}
    end
  end

  def selection_valid?(%__MODULE__{}, %{manifest_id: _other}), do: {:error, :stale_manifest}
  def selection_valid?(%__MODULE__{}, _selection), do: {:error, :invalid_selection}

  defp valid_route?({route_name, %{description: description, input_schema_hash: schema_hash}})
       when is_binary(route_name) and is_binary(description) and is_binary(schema_hash),
       do: true

  defp valid_route?(_route), do: false
end
