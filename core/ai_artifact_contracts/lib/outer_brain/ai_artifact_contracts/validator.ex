defmodule OuterBrain.AIArtifactContracts.Validator do
  @moduledoc false

  alias OuterBrain.AIArtifactContracts.Vocabulary

  @spec reject_raw_payload(map()) ::
          :ok | {:error, {:raw_ai_artifact_payload_forbidden, [term()]}}
  def reject_raw_payload(attrs) when is_map(attrs) do
    case raw_payload_path(attrs) do
      nil -> :ok
      path -> {:error, {:raw_ai_artifact_payload_forbidden, path}}
    end
  end

  @spec reject_out_of_scope_owner(map()) :: :ok | {:error, {:out_of_scope_owner, term()}}
  def reject_out_of_scope_owner(attrs) do
    cond do
      out_of_scope_owner?(value(attrs, :owner_scope)) ->
        {:error, {:out_of_scope_owner, value(attrs, :owner_scope)}}

      attrs |> value(:skill_ref) |> skill_owner_scope() |> out_of_scope_owner?() ->
        {:error, {:out_of_scope_owner, attrs |> value(:skill_ref) |> skill_owner_scope()}}

      true ->
        :ok
    end
  end

  @spec required(map(), [atom()]) :: :ok | {:error, {:missing_ai_artifact_ref, atom()}}
  def required(attrs, fields) do
    case Enum.find(fields, &(not present?(value(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_ai_artifact_ref, field}}
    end
  end

  @spec member(map(), atom(), [atom()]) ::
          {:ok, atom()} | {:error, {:invalid_ai_artifact_ref, atom()}}
  def member(attrs, field, allowed) do
    candidate = value(attrs, field)

    if candidate in allowed do
      {:ok, candidate}
    else
      {:error, {:invalid_ai_artifact_ref, field}}
    end
  end

  @spec outer_brain_owner(map()) :: {:ok, :outer_brain} | {:error, term()}
  def outer_brain_owner(attrs) do
    case value(attrs, :owner_scope) do
      :outer_brain ->
        {:ok, :outer_brain}

      "outer_brain" ->
        {:ok, :outer_brain}

      other when not is_nil(other) ->
        {:error, {:out_of_scope_owner, other}}

      _other ->
        {:error, {:invalid_ai_artifact_ref, :owner_scope}}
    end
  end

  @spec simple_ref(module(), map(), atom()) :: struct()
  def simple_ref(module, attrs, field) do
    struct(module, [
      {field, value!(attrs, field)},
      {:tenant_ref, value!(attrs, :tenant_ref)},
      {:trace_ref, value!(attrs, :trace_ref)},
      {:redaction_policy_ref, value!(attrs, :redaction_policy_ref)}
    ])
  end

  @spec value!(map(), atom()) :: term()
  def value!(attrs, field), do: value(attrs, field)

  @spec value(map(), atom()) :: term()
  def value(attrs, field) when is_map(attrs) and is_atom(field) do
    string_field = Atom.to_string(field)

    cond do
      Map.has_key?(attrs, field) -> Map.fetch!(attrs, field)
      Map.has_key?(attrs, string_field) -> Map.fetch!(attrs, string_field)
      true -> nil
    end
  end

  defp raw_payload_path(attrs) do
    Enum.find_value(Vocabulary.raw_keys(), &path_to_key(attrs, &1, []))
  end

  defp path_to_key(attrs, key, path) when is_map(attrs) do
    if Map.has_key?(attrs, key) do
      Enum.reverse([key | path])
    else
      Enum.find_value(attrs, fn {nested_key, value} ->
        path_to_key(value, key, [nested_key | path])
      end)
    end
  end

  defp path_to_key(items, key, path) when is_list(items) do
    items
    |> Enum.with_index()
    |> Enum.find_value(fn {value, index} ->
      path_to_key(value, key, [index | path])
    end)
  end

  defp path_to_key(_value, _key, _path), do: nil

  defp skill_owner_scope(%{} = skill_attrs), do: value(skill_attrs, :owner_scope)
  defp skill_owner_scope(_other), do: nil

  defp out_of_scope_owner?(owner),
    do: not is_nil(owner) and owner not in [:outer_brain, "outer_brain"]

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_list(value), do: value != []
  defp present?(value) when is_map(value), do: map_size(value) > 0
  defp present?(value), do: not is_nil(value)
end
