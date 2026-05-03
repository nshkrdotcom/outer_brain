defmodule OuterBrain.Prompting.ContextAdapterRegistry do
  @moduledoc """
  Registry-backed lookup for context adapter modules.
  """

  @spec resolve(map(), keyword()) :: {:ok, module()} | {:error, term()}
  def resolve(runtime_binding, opts \\ [])

  def resolve(runtime_binding, opts) when is_map(runtime_binding) and is_list(opts) do
    adapter_key = fetch_value(runtime_binding, :adapter_key)

    with key when is_binary(key) and byte_size(key) > 0 <- adapter_key,
         {:ok, registry} <- registry(opts),
         {:ok, module} <- Map.fetch(registry, key),
         true <- is_atom(module) and not is_nil(module) do
      {:ok, module}
    else
      nil -> {:error, :missing_adapter_key}
      {:error, reason} -> {:error, reason}
      :error -> {:error, {:adapter_not_registered, adapter_key}}
      _other -> {:error, {:adapter_not_registered, adapter_key}}
    end
  end

  def resolve(_runtime_binding, _opts), do: {:error, :invalid_runtime_binding}

  defp registry(opts) do
    registry = registry_config(opts)

    cond do
      is_map(registry) ->
        {:ok, registry}

      Keyword.keyword?(registry) ->
        {:ok, Map.new(registry)}

      true ->
        {:error, :invalid_adapter_registry}
    end
  end

  defp registry_config(opts) do
    case Keyword.fetch(opts, :adapter_registry) do
      {:ok, registry} ->
        registry

      :error ->
        standalone_application_env_registry(opts)
    end
  end

  defp standalone_application_env_registry(opts) do
    if Keyword.get(opts, :standalone_application_env?, false) do
      Application.get_env(:outer_brain_prompting, :context_adapters, %{})
    else
      %{}
    end
  end

  defp fetch_value(map, key) do
    Map.get(map, key) || Map.get(map, Atom.to_string(key))
  end
end
