defmodule OuterBrain.TokenMeter do
  @moduledoc """
  Deterministic token metering for governed provider effects.

  The meter accepts bounded token counts and refs only. It rejects raw payload
  bodies and executable provider hooks so counting cannot depend on provider calls.
  """

  defmodule TokenMeterRef do
    @moduledoc "Stable meter identity attached to provider effects."
    @enforce_keys [
      :meter_id,
      :provider_family,
      :model_ref,
      :tenant_ref,
      :installation_ref,
      :revision
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            meter_id: String.t(),
            provider_family: atom(),
            model_ref: String.t(),
            tenant_ref: String.t(),
            installation_ref: String.t(),
            revision: pos_integer()
          }
  end

  defmodule TokenCounts do
    @moduledoc "Four-class token count for one provider effect."
    @enforce_keys [
      :prompt_tokens,
      :completion_tokens,
      :cache_read_tokens,
      :cache_write_tokens
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            prompt_tokens: non_neg_integer(),
            completion_tokens: non_neg_integer(),
            cache_read_tokens: non_neg_integer(),
            cache_write_tokens: non_neg_integer()
          }
  end

  defmodule MeteredCall do
    @moduledoc "One metered call with bounded refs."
    @enforce_keys [
      :call_ref,
      :token_meter_ref,
      :operation_class,
      :excerpt_ref,
      :token_counts,
      :count_class,
      :rollup_key
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            call_ref: String.t(),
            token_meter_ref: TokenMeterRef.t(),
            operation_class: atom(),
            excerpt_ref: String.t(),
            token_counts: TokenCounts.t(),
            count_class: atom(),
            rollup_key: String.t()
          }
  end

  defmodule Rollup do
    @moduledoc "Workflow-level token rollup."
    @enforce_keys [:rollup_ref, :token_counts, :call_refs]
    defstruct @enforce_keys

    @type t :: %__MODULE__{
            rollup_ref: String.t(),
            token_counts: TokenCounts.t(),
            call_refs: [String.t()]
          }
  end

  @provider_families [
    :codex_cli,
    :claude_cli,
    :gemini_cli,
    :amp_cli,
    :github_http,
    :notion_http,
    :linear_http,
    :graphql,
    :realtime,
    :inference
  ]
  @operation_classes [
    :prompt,
    :completion,
    :tool_call,
    :http_request,
    :graphql_request,
    :stream_chunk,
    :inference_call
  ]
  @count_classes [:measured, :adapter_estimated, :bounded_fixture]
  @max_count 1_000_000
  @raw_keys [
    :body,
    :raw_body,
    :payload,
    :raw_payload,
    :prompt,
    :prompt_body,
    :completion,
    :completion_body,
    :tool_payload,
    :provider_payload,
    :model_output,
    :network_invoker,
    :provider_invoker,
    "body",
    "raw_body",
    "payload",
    "raw_payload",
    "prompt",
    "prompt_body",
    "completion",
    "completion_body",
    "tool_payload",
    "provider_payload",
    "model_output",
    "network_invoker",
    "provider_invoker"
  ]

  @type count_attrs :: map()

  @spec provider_families() :: [atom()]
  def provider_families, do: @provider_families

  @spec token_meter_ref(map()) :: {:ok, TokenMeterRef.t()} | {:error, term()}
  def token_meter_ref(attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:meter_id, :model_ref, :tenant_ref, :installation_ref]),
         {:ok, provider_family} <- member(attrs, :provider_family, @provider_families),
         {:ok, revision} <- positive_integer(attrs, :revision) do
      {:ok,
       %TokenMeterRef{
         meter_id: fetch!(attrs, :meter_id),
         provider_family: provider_family,
         model_ref: fetch!(attrs, :model_ref),
         tenant_ref: fetch!(attrs, :tenant_ref),
         installation_ref: fetch!(attrs, :installation_ref),
         revision: revision
       }}
    end
  end

  def token_meter_ref(_attrs), do: {:error, :invalid_token_meter_ref}

  @spec count_call(TokenMeterRef.t(), count_attrs()) :: {:ok, MeteredCall.t()} | {:error, term()}
  def count_call(%TokenMeterRef{} = ref, attrs) when is_map(attrs) do
    with :ok <- reject_raw(attrs),
         :ok <- required_strings(attrs, [:call_ref, :excerpt_ref, :rollup_key]),
         {:ok, operation_class} <- member(attrs, :operation_class, @operation_classes),
         {:ok, count_class} <- member(attrs, :count_class, @count_classes),
         {:ok, token_counts} <- token_counts(attrs) do
      {:ok,
       %MeteredCall{
         call_ref: fetch!(attrs, :call_ref),
         token_meter_ref: ref,
         operation_class: operation_class,
         excerpt_ref: fetch!(attrs, :excerpt_ref),
         token_counts: token_counts,
         count_class: count_class,
         rollup_key: fetch!(attrs, :rollup_key)
       }}
    end
  end

  def count_call(%TokenMeterRef{}, _attrs), do: {:error, :invalid_metered_call}

  @spec rollup([MeteredCall.t()]) :: {:ok, Rollup.t()} | {:error, term()}
  def rollup([%MeteredCall{} | _rest] = calls) do
    sorted_calls = Enum.sort_by(calls, & &1.call_ref)

    counts =
      Enum.reduce(sorted_calls, zero_counts(), fn call, acc ->
        add_counts(acc, call.token_counts)
      end)

    {:ok,
     %Rollup{
       rollup_ref: rollup_ref(sorted_calls),
       token_counts: counts,
       call_refs: Enum.map(sorted_calls, & &1.call_ref)
     }}
  end

  def rollup(_calls), do: {:error, :missing_metered_calls}

  @spec total_tokens(TokenCounts.t()) :: non_neg_integer()
  def total_tokens(%TokenCounts{} = counts) do
    counts.prompt_tokens + counts.completion_tokens + counts.cache_read_tokens +
      counts.cache_write_tokens
  end

  defp token_counts(attrs) do
    with {:ok, prompt_tokens} <- non_negative_count(attrs, :prompt_tokens),
         {:ok, completion_tokens} <- non_negative_count(attrs, :completion_tokens),
         {:ok, cache_read_tokens} <- non_negative_count(attrs, :cache_read_tokens),
         {:ok, cache_write_tokens} <- non_negative_count(attrs, :cache_write_tokens) do
      {:ok,
       %TokenCounts{
         prompt_tokens: prompt_tokens,
         completion_tokens: completion_tokens,
         cache_read_tokens: cache_read_tokens,
         cache_write_tokens: cache_write_tokens
       }}
    end
  end

  defp zero_counts do
    %TokenCounts{
      prompt_tokens: 0,
      completion_tokens: 0,
      cache_read_tokens: 0,
      cache_write_tokens: 0
    }
  end

  defp add_counts(left, right) do
    %TokenCounts{
      prompt_tokens: left.prompt_tokens + right.prompt_tokens,
      completion_tokens: left.completion_tokens + right.completion_tokens,
      cache_read_tokens: left.cache_read_tokens + right.cache_read_tokens,
      cache_write_tokens: left.cache_write_tokens + right.cache_write_tokens
    }
  end

  defp non_negative_count(attrs, field) do
    case fetch(attrs, field, 0) do
      value when is_integer(value) and value >= 0 and value <= @max_count ->
        {:ok, value}

      value when is_integer(value) and value > @max_count ->
        {:error, {:token_count_unbounded, field}}

      _value ->
        {:error, {:invalid_token_count, field}}
    end
  end

  defp required_strings(attrs, fields) do
    case Enum.find(fields, &(not present_string?(fetch(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_token_meter_ref, field}}
    end
  end

  defp member(attrs, field, allowed) do
    case fetch(attrs, field) do
      value when is_atom(value) -> member_atom(value, allowed, field)
      value when is_binary(value) -> member_string(value, allowed, field)
      _value -> {:error, {:unknown_token_meter_enum, field}}
    end
  end

  defp member_atom(value, allowed, field) do
    if value in allowed do
      {:ok, value}
    else
      {:error, {:unknown_token_meter_enum, field}}
    end
  end

  defp member_string(value, allowed, field) do
    case Enum.find(allowed, &(Atom.to_string(&1) == value)) do
      nil -> {:error, {:unknown_token_meter_enum, field}}
      found -> {:ok, found}
    end
  end

  defp positive_integer(attrs, field) do
    case fetch(attrs, field) do
      value when is_integer(value) and value > 0 -> {:ok, value}
      _value -> {:error, {:invalid_token_meter_ref, field}}
    end
  end

  defp rollup_ref(calls) do
    calls
    |> Enum.map_join("|", & &1.call_ref)
    |> hash()
    |> then(&("token-rollup://" <> &1))
  end

  defp reject_raw(attrs) do
    case Enum.find(@raw_keys, &Map.has_key?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_token_meter_payload_forbidden, key}}
    end
  end

  defp present_string?(value), do: is_binary(value) and String.trim(value) != ""
  defp fetch!(attrs, field), do: fetch(attrs, field)
  defp fetch(attrs, field), do: fetch(attrs, field, nil)

  defp fetch(attrs, field, default),
    do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field), default)

  defp hash(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)
end
