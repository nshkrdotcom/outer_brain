defmodule OuterBrain.Contracts.Phase4SemanticContract do
  @moduledoc false

  @scope_fields [
    :tenant_ref,
    :installation_ref,
    :workspace_ref,
    :project_ref,
    :environment_ref,
    :resource_ref,
    :authority_packet_ref,
    :permission_decision_ref,
    :idempotency_key,
    :trace_id,
    :correlation_id,
    :release_manifest_ref
  ]

  @forbidden_public_fields [
    :raw_prompt,
    :raw_provider_body,
    :raw_provider_payload,
    :provider_native_body,
    :raw_context_pack,
    :raw_artifact,
    :secret,
    :tenant_secret
  ]

  @sensitive_search_attribute_keys [
    "RawPrompt",
    "RawProviderBody",
    "RawProviderPayload",
    "ProviderNativeBody",
    "TenantId",
    "TenantRef",
    "Secret",
    "Credential"
  ]

  @spec scope_fields() :: [atom()]
  def scope_fields, do: @scope_fields

  @spec forbidden_public_fields() :: [atom()]
  def forbidden_public_fields, do: @forbidden_public_fields

  @spec required_scope(map()) :: :ok | {:error, term()}
  def required_scope(attrs) when is_map(attrs) do
    case required_strings(attrs, @scope_fields) do
      :ok -> required_actor(attrs)
      error -> error
    end
  end

  @spec required_actor(map()) :: :ok | {:error, term()}
  def required_actor(attrs) do
    case {string_value(attrs, :principal_ref), string_value(attrs, :system_actor_ref)} do
      {nil, nil} -> {:error, {:missing_one_of, [:principal_ref, :system_actor_ref]}}
      {_principal_ref, nil} -> :ok
      {nil, _system_actor_ref} -> :ok
      {_principal_ref, _system_actor_ref} -> :ok
    end
  end

  @spec required_strings(map(), [atom()]) :: :ok | {:error, term()}
  def required_strings(attrs, fields) do
    case Enum.find(fields, &(string_value(attrs, &1) == nil)) do
      nil -> :ok
      field -> {:error, {:missing_field, field}}
    end
  end

  @spec required_string(map(), atom()) :: {:ok, String.t()} | {:error, term()}
  def required_string(attrs, field) do
    case string_value(attrs, field) do
      nil -> {:error, {:missing_field, field}}
      value -> {:ok, value}
    end
  end

  @spec optional_string(map(), atom()) :: String.t() | nil
  def optional_string(attrs, field), do: string_value(attrs, field)

  @spec required_non_empty_list(map(), atom()) :: {:ok, list()} | {:error, term()}
  def required_non_empty_list(attrs, field) do
    case fetch_value(attrs, field) do
      list when is_list(list) and list != [] -> {:ok, list}
      _other -> {:error, {:missing_field, field}}
    end
  end

  @spec list_value(map(), atom()) :: list()
  def list_value(attrs, field) do
    case fetch_value(attrs, field) do
      list when is_list(list) -> list
      nil -> []
      other -> [other]
    end
  end

  @spec required_map(map(), atom()) :: {:ok, map()} | {:error, term()}
  def required_map(attrs, field) do
    case fetch_value(attrs, field) do
      value when is_map(value) -> {:ok, normalize_known_keys(value)}
      _other -> {:error, {:missing_field, field}}
    end
  end

  @spec string_value(map(), atom()) :: String.t() | nil
  def string_value(attrs, field) do
    case fetch_value(attrs, field) do
      value when is_binary(value) and value != "" -> value
      _other -> nil
    end
  end

  @spec fetch_value(map(), atom()) :: term()
  def fetch_value(%{__struct__: _} = attrs, field) do
    attrs
    |> Map.from_struct()
    |> fetch_value(field)
  end

  def fetch_value(attrs, field) when is_map(attrs) do
    Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
  end

  @spec normalize_known_keys(map()) :: map()
  def normalize_known_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) -> {String.to_existing_atom(key), value}
      {key, value} -> {key, value}
    end)
  rescue
    ArgumentError -> map
  end

  @spec atom_value(map(), atom(), [atom()]) :: {:ok, atom()} | {:error, term()}
  def atom_value(attrs, field, allowed) do
    case fetch_value(attrs, field) do
      value when is_atom(value) ->
        if value in allowed do
          {:ok, value}
        else
          {:error, {:invalid_enum, field}}
        end

      value when is_binary(value) ->
        atom_from_string(value, allowed, field)

      _other ->
        {:error, {:invalid_enum, field}}
    end
  end

  @spec string_enum(map(), atom(), [String.t()]) :: :ok | {:error, term()}
  def string_enum(attrs, field, allowed) do
    case string_value(attrs, field) do
      value when is_binary(value) ->
        if value in allowed do
          :ok
        else
          {:error, {:invalid_enum, field}}
        end

      _other ->
        {:error, {:invalid_enum, field}}
    end
  end

  @spec reject_forbidden_public_payload(map()) :: :ok | {:error, term()}
  def reject_forbidden_public_payload(payload) when is_map(payload) do
    case Enum.find(@forbidden_public_fields, &Map.has_key?(payload, &1)) do
      nil ->
        string_key =
          Enum.find(@forbidden_public_fields, fn field ->
            Map.has_key?(payload, Atom.to_string(field))
          end)

        if string_key do
          {:error, {:public_payload_leak, string_key}}
        else
          :ok
        end

      field ->
        {:error, {:public_payload_leak, field}}
    end
  end

  @spec reject_forbidden_attrs(map()) :: :ok | {:error, term()}
  def reject_forbidden_attrs(attrs) do
    case Enum.find(@forbidden_public_fields, &present?(attrs, &1)) do
      nil -> :ok
      field -> {:error, {:raw_payload_forbidden, field}}
    end
  end

  @spec reject_search_attribute_leaks(map()) :: :ok | {:error, term()}
  def reject_search_attribute_leaks(search_attributes) when is_map(search_attributes) do
    Enum.reduce_while(search_attributes, :ok, fn {key, value}, :ok ->
      cond do
        to_string(key) in @sensitive_search_attribute_keys ->
          {:halt, {:error, {:search_attribute_leak, to_string(key)}}}

        not scalar?(value) ->
          {:halt, {:error, {:search_attribute_not_scalar, to_string(key)}}}

        true ->
          {:cont, :ok}
      end
    end)
  end

  def reject_search_attribute_leaks(_search_attributes),
    do: {:error, {:missing_field, :search_attributes}}

  @spec present?(map(), atom()) :: boolean()
  def present?(attrs, field) do
    not is_nil(fetch_value(attrs, field))
  end

  defp atom_from_string(value, allowed, field) do
    case Enum.find(allowed, &(Atom.to_string(&1) == value)) do
      nil -> {:error, {:invalid_enum, field}}
      atom -> {:ok, atom}
    end
  end

  defp scalar?(value)
       when is_binary(value) or is_number(value) or is_boolean(value) or is_nil(value),
       do: true

  defp scalar?(_value), do: false
end
