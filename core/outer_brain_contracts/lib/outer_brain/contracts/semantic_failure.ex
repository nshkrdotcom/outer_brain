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

  defstruct [
    :kind,
    :retry_class,
    :tenant_id,
    :semantic_session_id,
    :causal_unit_id,
    :request_trace_id,
    :substrate_trace_id,
    :context_hash,
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
         {:ok, provider_ref} <- optional_map(source, :provider_ref),
         {:ok, operator_message} <- required_string(source, :operator_message) do
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
      provider_ref: failure.provider_ref,
      operator_message: failure.operator_message
    }
  end

  @spec journal_entry_id(t()) :: String.t()
  def journal_entry_id(%__MODULE__{} = failure) do
    [
      "semantic_failure",
      failure.semantic_session_id,
      failure.causal_unit_id,
      Atom.to_string(failure.kind)
    ]
    |> Enum.join(":")
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
end
