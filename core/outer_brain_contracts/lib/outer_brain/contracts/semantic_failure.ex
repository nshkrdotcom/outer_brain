defmodule OuterBrain.Contracts.SemanticFailure do
  @moduledoc """
  Provider-neutral semantic failure carrier.

  This contract is intentionally about semantic execution meaning, not provider
  mechanics. Provider-specific detail belongs in `provider_ref` or provenance.
  """

  @kinds [
    :semantic_invalid_output,
    :semantic_insufficient_context,
    :semantic_context_stale,
    :semantic_tool_mismatch,
    :semantic_provider_refusal,
    :semantic_provider_filtered,
    :semantic_loop_detected,
    :semantic_budget_exhausted,
    :semantic_adapter_unavailable
  ]

  @retry_classes [:retryable, :repairable, :clarification_required, :terminal]
  @journal_entry_prefix "semantic_failure_journal:v1:"
  @legacy_journal_entry_prefix "semantic_failure"
  @idempotency_alias_prefix "semantic_failure_idempotency_alias:v1:"
  @payload_hash_prefix "sha256:"

  defstruct [
    :kind,
    :retry_class,
    :tenant_id,
    :semantic_session_id,
    :causal_unit_id,
    :request_trace_id,
    :substrate_trace_id,
    :context_hash,
    :canonical_idempotency_key,
    :idempotency_alias,
    :provider_ref,
    :operator_message,
    provenance: []
  ]

  @type kind ::
          :semantic_invalid_output
          | :semantic_insufficient_context
          | :semantic_context_stale
          | :semantic_tool_mismatch
          | :semantic_provider_refusal
          | :semantic_provider_filtered
          | :semantic_loop_detected
          | :semantic_budget_exhausted
          | :semantic_adapter_unavailable

  @type retry_class :: :retryable | :repairable | :clarification_required | :terminal

  @type t :: %__MODULE__{
          kind: kind(),
          retry_class: retry_class(),
          tenant_id: String.t(),
          semantic_session_id: String.t(),
          causal_unit_id: String.t(),
          request_trace_id: String.t(),
          substrate_trace_id: String.t() | nil,
          provenance: [map()],
          context_hash: String.t() | nil,
          canonical_idempotency_key: String.t() | nil,
          idempotency_alias: String.t(),
          provider_ref: map() | nil,
          operator_message: String.t()
        }

  @spec kinds() :: [kind()]
  def kinds, do: @kinds

  @spec retry_classes() :: [retry_class()]
  def retry_classes, do: @retry_classes

  @spec new(map() | t(), map()) :: {:ok, t()} | {:error, term()}
  def new(attrs, defaults \\ %{})

  def new(%__MODULE__{} = failure, defaults) when is_map(defaults) do
    failure
    |> to_map()
    |> Map.merge(defaults, fn _key, value, _default -> value end)
    |> new(%{})
  end

  def new(attrs, defaults) when is_map(attrs) and is_map(defaults) do
    source = Map.merge(defaults, attrs)

    with {:ok, kind} <- semantic_kind(source),
         {:ok, retry_class} <- retry_class(source, kind),
         {:ok, tenant_id} <- required_string(source, :tenant_id),
         {:ok, semantic_session_id} <- required_string(source, :semantic_session_id),
         {:ok, causal_unit_id} <- required_string(source, :causal_unit_id),
         {:ok, request_trace_id} <- required_string(source, :request_trace_id),
         {:ok, substrate_trace_id} <- optional_string(source, :substrate_trace_id),
         {:ok, provenance} <- provenance(source),
         {:ok, context_hash} <- optional_string(source, :context_hash),
         {:ok, canonical_idempotency_key} <- optional_string(source, :canonical_idempotency_key),
         {:ok, idempotency_alias} <- optional_string(source, :idempotency_alias),
         {:ok, provider_ref} <- optional_map(source, :provider_ref),
         {:ok, operator_message} <- required_string(source, :operator_message) do
      idempotency_alias =
        idempotency_alias ||
          default_idempotency_alias(
            tenant_id,
            semantic_session_id,
            causal_unit_id,
            kind,
            request_trace_id,
            substrate_trace_id,
            context_hash
          )

      {:ok,
       %__MODULE__{
         kind: kind,
         retry_class: retry_class,
         tenant_id: tenant_id,
         semantic_session_id: semantic_session_id,
         causal_unit_id: causal_unit_id,
         request_trace_id: request_trace_id,
         substrate_trace_id: substrate_trace_id,
         provenance: provenance,
         context_hash: context_hash,
         canonical_idempotency_key: canonical_idempotency_key,
         idempotency_alias: idempotency_alias,
         provider_ref: provider_ref,
         operator_message: operator_message
       }}
    end
  end

  def new(_attrs, _defaults), do: {:error, :invalid_semantic_failure}

  @spec from_payload(map()) :: {:ok, t()} | {:error, term()}
  def from_payload(payload), do: new(payload)

  @spec to_payload(t()) :: map()
  def to_payload(%__MODULE__{} = failure) do
    %{
      "kind" => Atom.to_string(failure.kind),
      "retry_class" => Atom.to_string(failure.retry_class),
      "tenant_id" => failure.tenant_id,
      "semantic_session_id" => failure.semantic_session_id,
      "causal_unit_id" => failure.causal_unit_id,
      "request_trace_id" => failure.request_trace_id,
      "substrate_trace_id" => failure.substrate_trace_id,
      "provenance" => failure.provenance,
      "context_hash" => failure.context_hash,
      "canonical_idempotency_key" => failure.canonical_idempotency_key,
      "idempotency_alias" => failure.idempotency_alias,
      "provider_ref" => failure.provider_ref,
      "operator_message" => failure.operator_message
    }
  end

  @spec to_map(t()) :: map()
  def to_map(%__MODULE__{} = failure) do
    %{
      kind: failure.kind,
      retry_class: failure.retry_class,
      tenant_id: failure.tenant_id,
      semantic_session_id: failure.semantic_session_id,
      causal_unit_id: failure.causal_unit_id,
      request_trace_id: failure.request_trace_id,
      substrate_trace_id: failure.substrate_trace_id,
      provenance: failure.provenance,
      context_hash: failure.context_hash,
      canonical_idempotency_key: failure.canonical_idempotency_key,
      idempotency_alias: failure.idempotency_alias,
      provider_ref: failure.provider_ref,
      operator_message: failure.operator_message
    }
  end

  @spec journal_entry_id(t()) :: String.t()
  def journal_entry_id(%__MODULE__{} = failure) do
    @journal_entry_prefix <> sha256(canonical_json(journal_identity_payload(failure)))
  end

  @spec journal_identity_payload(t()) :: map()
  def journal_identity_payload(%__MODULE__{} = failure) do
    idempotency_ref = failure.canonical_idempotency_key || failure.idempotency_alias

    %{
      "tenant_id" => failure.tenant_id,
      "semantic_session_id" => failure.semantic_session_id,
      "causal_unit_id" => failure.causal_unit_id,
      "kind" => Atom.to_string(failure.kind),
      "request_trace_id" => failure.request_trace_id,
      "substrate_trace_id" => failure.substrate_trace_id,
      "context_hash" => failure.context_hash,
      "canonical_idempotency_key" => failure.canonical_idempotency_key,
      "idempotency_alias" => idempotency_alias_for_identity(failure),
      "idempotency_ref" => idempotency_ref,
      "idempotency_ref_kind" => idempotency_ref_kind(failure),
      "semantic_failure_payload_hash" => semantic_failure_payload_hash(failure)
    }
  end

  @spec semantic_failure_payload_hash(t()) :: String.t()
  def semantic_failure_payload_hash(%__MODULE__{} = failure) do
    @payload_hash_prefix <> sha256(canonical_json(to_payload(failure)))
  end

  @spec legacy_journal_entry_id(t()) :: String.t()
  def legacy_journal_entry_id(%__MODULE__{} = failure) do
    [
      @legacy_journal_entry_prefix,
      failure.semantic_session_id,
      failure.causal_unit_id,
      Atom.to_string(failure.kind)
    ]
    |> Enum.join(":")
  end

  @spec legacy_journal_entry_alias(t()) :: map()
  def legacy_journal_entry_alias(%__MODULE__{} = failure) do
    legacy_id = legacy_journal_entry_id(failure)

    %{
      "alias_type" => "read_only_legacy_semantic_failure_journal_id",
      "alias_id" => legacy_id,
      "canonical_entry_id" => journal_entry_id(failure),
      "source_ref" => "phase5-v7-m5-semantic-failure-journal-identity",
      "expires_after" => "legacy semantic failure journal migration",
      "parse_result" => legacy_journal_entry_parse_result(legacy_id)
    }
  end

  @spec parse_legacy_journal_entry_id(String.t()) :: {:ok, map()} | {:error, term()}
  def parse_legacy_journal_entry_id(entry_id) when is_binary(entry_id) do
    case String.split(entry_id, ":") do
      [@legacy_journal_entry_prefix, session_id, causal_unit_id, kind_string] ->
        case atom_from_string(kind_string, @kinds) do
          nil ->
            {:error, {:legacy_semantic_failure_journal_id_unknown_kind, kind_string}}

          kind_atom ->
            {:ok,
             %{
               "semantic_session_id" => session_id,
               "causal_unit_id" => causal_unit_id,
               "kind" => Atom.to_string(kind_atom)
             }}
        end

      _other ->
        {:error, :legacy_semantic_failure_journal_id_ambiguous}
    end
  end

  @spec legacy_journal_entry_id_scan([String.t()]) :: map()
  def legacy_journal_entry_id_scan(entry_ids) when is_list(entry_ids) do
    {legacy_ids, non_legacy_ids} =
      Enum.split_with(entry_ids, &String.starts_with?(&1, @legacy_journal_entry_prefix <> ":"))

    %{
      "source_ref" => "phase5-v7-m5-semantic-failure-journal-identity",
      "legacy_ids" => legacy_ids,
      "non_legacy_ids" => non_legacy_ids,
      "ambiguous_legacy_ids" =>
        Enum.filter(legacy_ids, &match?({:error, _reason}, parse_legacy_journal_entry_id(&1))),
      "duplicate_legacy_ids" => duplicate_values(legacy_ids)
    }
  end

  @spec default_retry_class(kind()) :: retry_class()
  def default_retry_class(:semantic_invalid_output), do: :repairable
  def default_retry_class(:semantic_insufficient_context), do: :clarification_required
  def default_retry_class(:semantic_context_stale), do: :retryable
  def default_retry_class(:semantic_tool_mismatch), do: :repairable
  def default_retry_class(:semantic_provider_refusal), do: :repairable
  def default_retry_class(:semantic_provider_filtered), do: :terminal
  def default_retry_class(:semantic_loop_detected), do: :terminal
  def default_retry_class(:semantic_budget_exhausted), do: :repairable
  def default_retry_class(:semantic_adapter_unavailable), do: :retryable

  defp semantic_kind(source) do
    case fetch_value(source, :kind) do
      value when is_atom(value) and value in @kinds ->
        {:ok, value}

      value when is_binary(value) ->
        if atom = atom_from_string(value, @kinds) do
          {:ok, atom}
        else
          {:error, {:invalid_semantic_failure_kind, value}}
        end

      value ->
        {:error, {:invalid_semantic_failure_kind, value}}
    end
  end

  defp retry_class(source, kind) do
    case fetch_value(source, :retry_class) do
      nil ->
        {:ok, default_retry_class(kind)}

      value when is_atom(value) and value in @retry_classes ->
        {:ok, value}

      value when is_binary(value) ->
        if atom = atom_from_string(value, @retry_classes) do
          {:ok, atom}
        else
          {:error, {:invalid_semantic_failure_retry_class, value}}
        end

      value ->
        {:error, {:invalid_semantic_failure_retry_class, value}}
    end
  end

  defp required_string(source, key) do
    case fetch_value(source, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, {:missing_semantic_failure_field, key}}
    end
  end

  defp optional_string(source, key) do
    case fetch_value(source, key) do
      nil -> {:ok, nil}
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, {:invalid_semantic_failure_string, key}}
    end
  end

  defp optional_map(source, key) do
    case fetch_value(source, key) do
      nil -> {:ok, nil}
      value when is_map(value) -> {:ok, normalize_nested_map(value)}
      _other -> {:error, {:invalid_semantic_failure_map, key}}
    end
  end

  defp default_idempotency_alias(
         tenant_id,
         semantic_session_id,
         causal_unit_id,
         kind,
         request_trace_id,
         substrate_trace_id,
         context_hash
       ) do
    @idempotency_alias_prefix <>
      sha256(
        canonical_json(%{
          "tenant_id" => tenant_id,
          "semantic_session_id" => semantic_session_id,
          "causal_unit_id" => causal_unit_id,
          "kind" => Atom.to_string(kind),
          "request_trace_id" => request_trace_id,
          "substrate_trace_id" => substrate_trace_id,
          "context_hash" => context_hash
        })
      )
  end

  defp idempotency_ref_kind(%__MODULE__{canonical_idempotency_key: key})
       when is_binary(key) and key != "",
       do: "canonical_idempotency_key"

  defp idempotency_ref_kind(_failure), do: "declared_alias"

  defp idempotency_alias_for_identity(%__MODULE__{canonical_idempotency_key: key})
       when is_binary(key) and key != "",
       do: nil

  defp idempotency_alias_for_identity(%__MODULE__{} = failure), do: failure.idempotency_alias

  defp legacy_journal_entry_parse_result(legacy_id) do
    case parse_legacy_journal_entry_id(legacy_id) do
      {:ok, parsed} -> %{"status" => "parseable", "parsed" => parsed}
      {:error, reason} -> %{"status" => "ambiguous", "reason" => inspect(reason)}
    end
  end

  defp duplicate_values(values) do
    values
    |> Enum.frequencies()
    |> Enum.filter(fn {_value, count} -> count > 1 end)
    |> Enum.map(fn {value, _count} -> value end)
  end

  defp provenance(source) do
    case fetch_value(source, :provenance) do
      nil ->
        {:ok, []}

      list when is_list(list) ->
        if Enum.all?(list, &is_map/1) do
          {:ok, Enum.map(list, &normalize_nested_map/1)}
        else
          {:error, :invalid_semantic_failure_provenance}
        end

      _other ->
        {:error, :invalid_semantic_failure_provenance}
    end
  end

  defp normalize_nested_map(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_map(value) -> {to_string(key), normalize_nested_map(value)}
      {key, value} -> {to_string(key), value}
    end)
  end

  defp fetch_value(source, key) do
    Map.get(source, key) || Map.get(source, Atom.to_string(key))
  end

  defp atom_from_string(value, allowed) do
    Enum.find(allowed, &(Atom.to_string(&1) == value))
  end

  defp sha256(value), do: :crypto.hash(:sha256, value) |> Base.encode16(case: :lower)

  defp canonical_json(value),
    do: value |> canonical_value() |> encode_json_value() |> IO.iodata_to_binary()

  defp canonical_value(%_{} = value), do: value |> Map.from_struct() |> canonical_value()

  defp canonical_value(value) when is_map(value) do
    Map.new(value, fn {key, nested} -> {to_string(key), canonical_value(nested)} end)
  end

  defp canonical_value(value) when is_list(value), do: Enum.map(value, &canonical_value/1)
  defp canonical_value(value) when is_atom(value), do: Atom.to_string(value)
  defp canonical_value(value), do: value

  defp encode_json_value(nil), do: "null"
  defp encode_json_value(true), do: "true"
  defp encode_json_value(false), do: "false"
  defp encode_json_value(value) when is_binary(value), do: [?\", escape_string(value), ?\"]
  defp encode_json_value(value) when is_integer(value), do: Integer.to_string(value)

  defp encode_json_value(value) when is_float(value) do
    :erlang.float_to_binary(value, [:short, :compact])
  end

  defp encode_json_value(value) when is_list(value) do
    [?[, value |> Enum.map(&encode_json_value/1) |> Enum.intersperse(","), ?]]
  end

  defp encode_json_value(value) when is_map(value) do
    entries =
      value
      |> Enum.map(fn {key, nested} -> {to_string(key), nested} end)
      |> Enum.sort_by(fn {key, _nested} -> key end)
      |> Enum.map(fn {key, nested} -> [encode_json_value(key), ?:, encode_json_value(nested)] end)

    [?{, Enum.intersperse(entries, ","), ?}]
  end

  defp escape_string(<<>>), do: []
  defp escape_string(<<"\"", rest::binary>>), do: [?\\, ?", escape_string(rest)]
  defp escape_string(<<"\\", rest::binary>>), do: [?\\, ?\\, escape_string(rest)]
  defp escape_string(<<"\b", rest::binary>>), do: [?\\, ?b, escape_string(rest)]
  defp escape_string(<<"\f", rest::binary>>), do: [?\\, ?f, escape_string(rest)]
  defp escape_string(<<"\n", rest::binary>>), do: [?\\, ?n, escape_string(rest)]
  defp escape_string(<<"\r", rest::binary>>), do: [?\\, ?r, escape_string(rest)]
  defp escape_string(<<"\t", rest::binary>>), do: [?\\, ?t, escape_string(rest)]

  defp escape_string(<<char::utf8, rest::binary>>) when char < 0x20 do
    [?\\, ?u, char |> Integer.to_string(16) |> String.pad_leading(4, "0"), escape_string(rest)]
  end

  defp escape_string(<<char::utf8, rest::binary>>), do: [<<char::utf8>>, escape_string(rest)]
end
