defmodule OuterBrain.ContextABI.Validator do
  @moduledoc false

  alias OuterBrain.ContextABI.Failure

  @raw_keys MapSet.new(~w(
                access_token
                api_key
                authorization
                credential
                credential_material
                memory_body
                memory_content
                model_output
                password
                payload
                prompt
                prompt_body
                prompt_content
                prompt_text
                provider_payload
                provider_response
                raw
                raw_memory
                raw_payload
                raw_prompt
                raw_provider_payload
                refresh_token
                request_body
                response_body
                secret
                secret_token
                stderr
                stdout
                token
              ))

  @spec reject_raw_payload(term()) :: :ok | {:error, Failure.t()}
  def reject_raw_payload(value) do
    case find_raw_key(value) do
      nil ->
        :ok

      key ->
        failure(:outer_brain, "outer_brain.context.raw_payload_rejected.v1",
          safe_message: "raw context payloads are not allowed in Context ABI contracts",
          evidence_refs: ["field://#{key}"]
        )
    end
  end

  @spec required_string(map(), atom()) :: {:ok, String.t()} | {:error, Failure.t()}
  def required_string(attrs, field) do
    case fetch(attrs, field) do
      value when is_binary(value) and value != "" ->
        {:ok, value}

      _other ->
        failure(:outer_brain, "outer_brain.context.missing_required_context.v1",
          safe_message: "required context field is missing",
          evidence_refs: ["field://#{Atom.to_string(field)}"]
        )
    end
  end

  @spec string_list(map(), atom()) :: {:ok, [String.t()]} | {:error, Failure.t()}
  def string_list(attrs, field) do
    case fetch(attrs, field, []) do
      values when is_list(values) ->
        if Enum.all?(values, &(is_binary(&1) and &1 != "")) do
          {:ok, values}
        else
          invalid_field(field)
        end

      _other ->
        invalid_field(field)
    end
  end

  @spec optional_map(map(), atom()) :: {:ok, map()} | {:error, Failure.t()}
  def optional_map(attrs, field) do
    case fetch(attrs, field, %{}) do
      value when is_map(value) -> {:ok, value}
      _other -> invalid_field(field)
    end
  end

  @spec member(map(), atom(), [atom()], String.t()) :: {:ok, atom()} | {:error, Failure.t()}
  def member(attrs, field, allowed, reason_code) do
    case fetch(attrs, field) do
      value when is_atom(value) ->
        if value in allowed, do: {:ok, value}, else: invalid_enum(reason_code)

      value when is_binary(value) ->
        Enum.find(allowed, &(Atom.to_string(&1) == value))
        |> case do
          nil -> invalid_enum(reason_code)
          found -> {:ok, found}
        end

      _other ->
        invalid_enum(reason_code)
    end
  end

  @spec failure(Failure.owner(), String.t(), keyword()) :: {:error, Failure.t()}
  def failure(owner, reason_code, opts) do
    {:ok, failure} =
      Failure.new(%{
        owner: owner,
        reason_code: reason_code,
        safe_message: Keyword.fetch!(opts, :safe_message),
        retryable?: Keyword.get(opts, :retryable?, false),
        trace_ref: Keyword.get(opts, :trace_ref),
        evidence_refs: Keyword.get(opts, :evidence_refs, [])
      })

    {:error, failure}
  end

  @spec fetch(map(), atom(), term()) :: term()
  def fetch(attrs, field, default \\ nil)

  def fetch(%{__struct__: _} = attrs, field, default),
    do: attrs |> Map.from_struct() |> fetch(field, default)

  def fetch(attrs, field, default),
    do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field), default)

  defp invalid_field(field) do
    failure(:outer_brain, "outer_brain.context.invalid_field.v1",
      safe_message: "context field is invalid",
      evidence_refs: ["field://#{Atom.to_string(field)}"]
    )
  end

  defp invalid_enum(reason_code) do
    failure(:outer_brain, reason_code, safe_message: "context vocabulary value is invalid")
  end

  defp find_raw_key(%{__struct__: _} = value), do: value |> Map.from_struct() |> find_raw_key()

  defp find_raw_key(%{} = map) do
    Enum.find_value(map, fn {key, value} ->
      key_string = key |> to_string() |> String.downcase()

      cond do
        MapSet.member?(@raw_keys, key_string) -> key_string
        String.starts_with?(key_string, "raw_") -> key_string
        true -> find_raw_key(value)
      end
    end)
  end

  defp find_raw_key(values) when is_list(values), do: Enum.find_value(values, &find_raw_key/1)
  defp find_raw_key(_value), do: nil
end
