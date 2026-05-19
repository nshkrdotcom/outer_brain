defmodule OuterBrain.MemoryContracts.Validator do
  @moduledoc false

  alias OuterBrain.MemoryContracts.Vocabulary

  @spec fetch_value(map(), atom()) :: term()
  def fetch_value(attrs, field) when is_map(attrs) and is_atom(field) do
    string_field = Atom.to_string(field)

    cond do
      Map.has_key?(attrs, field) -> Map.fetch!(attrs, field)
      Map.has_key?(attrs, string_field) -> Map.fetch!(attrs, string_field)
      true -> nil
    end
  end

  @spec required_ref_fields(map()) :: :ok | {:error, {:missing_required_ref, atom()}}
  def required_ref_fields(attrs) do
    case Enum.find(Vocabulary.required_refs(), &(required_string(attrs, &1) |> missing?())) do
      nil -> :ok
      field -> {:error, {:missing_required_ref, field}}
    end
  end

  @spec required_string(map(), atom()) :: {:ok, String.t()} | {:error, {:missing_field, atom()}}
  def required_string(attrs, field) do
    case fetch_value(attrs, field) do
      value when is_binary(value) ->
        if String.trim(value) == "", do: {:error, {:missing_field, field}}, else: {:ok, value}

      _other ->
        {:error, {:missing_field, field}}
    end
  end

  @spec optional_string(map(), atom()) :: String.t() | nil
  def optional_string(attrs, field) do
    case fetch_value(attrs, field) do
      value when is_binary(value) and value != "" -> value
      _other -> nil
    end
  end

  @spec bounded_optional_refs(map(), [atom()]) :: :ok | {:error, {:invalid_scope_ref, atom()}}
  def bounded_optional_refs(attrs, fields) do
    case Enum.find(fields, fn field ->
           value = fetch_value(attrs, field)
           not (is_nil(value) or (is_binary(value) and String.trim(value) != ""))
         end) do
      nil -> :ok
      field -> {:error, {:invalid_scope_ref, field}}
    end
  end

  @spec required_member(map(), atom(), [atom()]) ::
          {:ok, atom()} | {:error, {:invalid_field, atom()}}
  def required_member(attrs, field, allowed) do
    value = fetch_value(attrs, field)

    if value in allowed do
      {:ok, value}
    else
      {:error, {:invalid_field, field}}
    end
  end

  @spec optional_member(map(), atom(), [atom()]) :: atom() | nil
  def optional_member(attrs, field, allowed) do
    value = fetch_value(attrs, field)
    if value in allowed, do: value
  end

  @spec required_positive_integer(map(), atom()) ::
          {:ok, pos_integer()} | {:error, {:invalid_field, atom()}}
  def required_positive_integer(attrs, field) do
    case fetch_value(attrs, field) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _other -> {:error, {:invalid_field, field}}
    end
  end

  @spec required_non_negative_integer(map(), atom()) ::
          {:ok, non_neg_integer()} | {:error, {:invalid_field, atom()}}
  def required_non_negative_integer(attrs, field) do
    case fetch_value(attrs, field) do
      value when is_integer(value) and value >= 0 -> {:ok, value}
      _other -> {:error, {:invalid_field, field}}
    end
  end

  @spec allowed_decision_reason(map(), atom()) ::
          :ok | {:error, :unexpected_budget_denial_reason | :missing_budget_denial_reason}
  def allowed_decision_reason(attrs, decision) do
    reason = fetch_value(attrs, :reason)

    cond do
      decision in [:allow, :allow_with_redaction] and is_nil(reason) -> :ok
      decision in [:allow, :allow_with_redaction] -> {:error, :unexpected_budget_denial_reason}
      reason in Vocabulary.budget_exhaustion_reasons() -> :ok
      true -> {:error, :missing_budget_denial_reason}
    end
  end

  @spec reject_raw_payload(map()) ::
          :ok | {:error, {:raw_memory_body_forbidden, atom() | String.t()}}
  def reject_raw_payload(attrs) when is_map(attrs) do
    case Enum.find(Vocabulary.raw_payload_keys(), &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_memory_body_forbidden, key}}
    end
  end

  defp missing?({:ok, _value}), do: false
  defp missing?({:error, _reason}), do: true
end
