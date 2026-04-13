defmodule OuterBrain.Core.TurnSelector do
  @moduledoc """
  Pure route-selection helper for semantic turns over a manifest snapshot.
  """

  alias OuterBrain.Contracts.ToolManifestSnapshot

  @type selection :: %{
          required(:request_id) => String.t(),
          required(:manifest_id) => String.t(),
          required(:schema_hash) => String.t(),
          required(:route) => String.t(),
          required(:args) => map(),
          required(:provenance) => map()
        }

  @spec select(ToolManifestSnapshot.t(), String.t(), keyword()) ::
          {:ok, selection(), float()} | {:error, term()}
  def select(%ToolManifestSnapshot{} = snapshot, text, opts \\ []) when is_binary(text) do
    trimmed = String.trim(text)

    with :ok <- validate_text(trimmed),
         {:ok, request_id} <- required_string(opts, :request_id),
         {:ok, route_name, selector_reason} <- choose_route(snapshot, trimmed, opts) do
      {:ok,
       %{
         request_id: request_id,
         manifest_id: snapshot.manifest_id,
         schema_hash: snapshot.schema_hash,
         route: route_name,
         args: build_args(route_name, trimmed, snapshot, opts),
         provenance: %{
           selector: selector_reason,
           scope_id: Keyword.get(opts, :scope_id),
           turn_text: trimmed
         }
       }, confidence(selector_reason)}
    end
  end

  defp validate_text(""), do: {:error, :blank_turn}
  defp validate_text(_text), do: :ok

  defp required_string(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, {:missing_option, key}}
    end
  end

  defp choose_route(%ToolManifestSnapshot{routes: routes}, text, opts) do
    case normalize_route_name(Keyword.get(opts, :route)) do
      nil ->
        choose_route_from_text(routes, text)

      route_name ->
        if Map.has_key?(routes, route_name) do
          {:ok, route_name, :explicit_route}
        else
          {:error, :route_not_present}
        end
    end
  end

  defp choose_route_from_text(routes, text) do
    cond do
      compile_workspace_match?(routes, text) ->
        {:ok, "compile_workspace", :keyword_compile_workspace}

      map_size(routes) == 1 ->
        {route_name, _route_metadata} = Enum.at(routes, 0)
        {:ok, route_name, :single_route_manifest}

      true ->
        {:error, :clarification_required}
    end
  end

  defp compile_workspace_match?(routes, text) do
    lowered = String.downcase(text)

    Map.has_key?(routes, "compile_workspace") and
      String.contains?(lowered, "compile") and
      String.contains?(lowered, "workspace")
  end

  defp build_args("compile_workspace", _text, %ToolManifestSnapshot{routes: routes}, opts) do
    route_metadata = Map.fetch!(routes, "compile_workspace")

    %{
      workspace_id:
        Keyword.get(opts, :workspace_id) ||
          Keyword.get(opts, :scope_id) ||
          example_workspace_id(route_metadata) ||
          "workspace/main"
    }
    |> maybe_put_workspace_root(opts)
  end

  defp build_args("reply_to_user", text, _snapshot, _opts), do: %{body: text}

  defp build_args(route_name, _text, %ToolManifestSnapshot{routes: routes}, _opts) do
    routes
    |> Map.fetch!(route_name)
    |> Map.get(:examples, [])
    |> List.first()
    |> case do
      %{} = example -> example
      _other -> %{}
    end
  end

  defp maybe_put_workspace_root(args, opts) do
    case Keyword.get(opts, :workspace_root) do
      value when is_binary(value) and value != "" -> Map.put(args, :workspace_root, value)
      _other -> args
    end
  end

  defp example_workspace_id(route_metadata) do
    route_metadata
    |> Map.get(:examples, [])
    |> List.first()
    |> case do
      %{workspace_id: workspace_id} when is_binary(workspace_id) and workspace_id != "" ->
        workspace_id

      _other ->
        nil
    end
  end

  defp normalize_route_name(nil), do: nil
  defp normalize_route_name(value) when is_atom(value), do: Atom.to_string(value)
  defp normalize_route_name(value) when is_binary(value) and value != "", do: value
  defp normalize_route_name(_value), do: nil

  defp confidence(:explicit_route), do: 1.0
  defp confidence(:keyword_compile_workspace), do: 0.92
  defp confidence(:single_route_manifest), do: 0.8
end
