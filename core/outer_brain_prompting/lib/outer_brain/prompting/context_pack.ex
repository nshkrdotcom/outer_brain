defmodule OuterBrain.Prompting.ContextPack do
  @moduledoc """
  Builds a replayable context pack from semantic state and durable references.
  """

  alias OuterBrain.Core.SemanticFrame
  alias OuterBrain.Prompting.{ContextAdapterRegistry, ContextFragment}

  @spec build(SemanticFrame.t(), [String.t()], keyword()) :: map()
  def build(%SemanticFrame{} = frame, refs, opts \\ []) when is_list(refs) do
    base_pack = %{
      session_id: frame.session_id,
      objective: frame.objective,
      unresolved_questions: frame.unresolved_questions,
      commitments: frame.commitments,
      refs: Enum.uniq(refs),
      mode: Keyword.get(opts, :mode, :reply),
      trace_id: Keyword.get(opts, :trace_id)
    }

    context_sources = Keyword.get(opts, :context_sources, [])
    context_bindings = normalize_bindings(Keyword.get(opts, :context_bindings, %{}))

    reports =
      Enum.map(context_sources, fn source ->
        fetch_source_report(base_pack, source, context_bindings, opts)
      end)

    fragments = Enum.flat_map(reports, & &1.fragments)

    base_pack
    |> Map.merge(%{
      fragments: fragments,
      context_sources: Enum.map(reports, &Map.delete(&1, :fragments))
    })
    |> enforce_context_budget(fragments, Keyword.get(opts, :context_budget))
  end

  defp enforce_context_budget(pack, _fragments, nil), do: pack

  defp enforce_context_budget(pack, fragments, budget) when is_map(budget) do
    max_context_bytes = fetch_value(budget, :max_context_bytes)
    current_context_bytes = fetch_value(budget, :current_context_bytes) || 0
    append_context_bytes = context_fragment_bytes(fragments)
    projected_context_bytes = current_context_bytes + append_context_bytes

    report =
      %{
        budget_ref: fetch_value(budget, :budget_ref),
        budget_scope: fetch_value(budget, :budget_scope),
        enforcement_point: fetch_value(budget, :enforcement_point) || :tool_result_append,
        max_context_bytes: max_context_bytes,
        current_context_bytes: current_context_bytes,
        append_context_bytes: append_context_bytes,
        projected_context_bytes: projected_context_bytes
      }

    cond do
      not is_integer(max_context_bytes) or max_context_bytes < 0 ->
        pack
        |> Map.put(:fragments, [])
        |> Map.put(:context_budget, Map.put(report, :decision, :quarantine_meter_unavailable))

      projected_context_bytes > max_context_bytes ->
        pack
        |> Map.put(:fragments, [])
        |> Map.put(:context_budget, Map.put(report, :decision, :reject_context_append))

      true ->
        Map.put(pack, :context_budget, Map.put(report, :decision, :allow))
    end
  end

  defp enforce_context_budget(pack, fragments, _budget) do
    report = %{
      budget_ref: nil,
      budget_scope: nil,
      enforcement_point: :tool_result_append,
      max_context_bytes: nil,
      current_context_bytes: 0,
      append_context_bytes: context_fragment_bytes(fragments),
      projected_context_bytes: context_fragment_bytes(fragments),
      decision: :quarantine_meter_unavailable
    }

    pack
    |> Map.put(:fragments, [])
    |> Map.put(:context_budget, report)
  end

  defp context_fragment_bytes(fragments) do
    fragments
    |> :erlang.term_to_binary()
    |> byte_size()
  end

  defp fetch_source_report(base_pack, source, context_bindings, opts) do
    config = source_report_config(source, context_bindings)
    report = base_source_report(config)

    cond do
      is_nil(base_pack.trace_id) ->
        %{report | error: :missing_trace_id}

      not is_map(config.runtime_binding) ->
        %{report | error: :binding_not_found}

      true ->
        fetch_bound_source_report(base_pack, config, report, opts)
    end
  end

  defp source_report_config(source, context_bindings) do
    binding_key = fetch_value(source, :binding_key)

    %{
      source_ref: fetch_value(source, :source_ref),
      binding_key: binding_key,
      usage_phase: fetch_value(source, :usage_phase),
      required?: fetch_value(source, :required?) || false,
      schema_ref: fetch_value(source, :schema_ref),
      max_fragments: fetch_value(source, :max_fragments) || 5,
      merge_strategy: fetch_value(source, :merge_strategy) || :append,
      timeout_ms: fetch_value(source, :timeout_ms) || 1_000,
      runtime_binding: Map.get(context_bindings, binding_key)
    }
  end

  defp base_source_report(config) do
    %{
      source_ref: config.source_ref,
      binding_key: config.binding_key,
      usage_phase: config.usage_phase,
      required?: config.required?,
      schema_ref: config.schema_ref,
      merge_strategy: config.merge_strategy,
      status: :degraded,
      adapter_key: nil,
      fragment_count: 0,
      error: nil,
      fragments: []
    }
  end

  defp fetch_bound_source_report(base_pack, config, report, opts) do
    runtime_binding = config.runtime_binding
    adapter_key = fetch_value(runtime_binding, :adapter_key)
    timeout_ms = fetch_value(runtime_binding, :timeout_ms) || config.timeout_ms

    case ContextAdapterRegistry.resolve(runtime_binding, opts) do
      {:ok, adapter} ->
        do_fetch_bound_source_report(base_pack, config, report, adapter, adapter_key, timeout_ms)

      {:error, reason} ->
        %{report | adapter_key: adapter_key, error: reason}
    end
  end

  defp do_fetch_bound_source_report(base_pack, config, report, adapter, adapter_key, timeout_ms) do
    request = context_source_request(base_pack, config)

    case fetch_fragments(adapter, request, config.runtime_binding, timeout_ms) do
      {:ok, fragments} ->
        fragments
        |> normalize_source_fragments(config, adapter_key)
        |> successful_source_report(report, config, adapter_key)

      {:error, reason} ->
        %{report | adapter_key: adapter_key, error: reason}
    end
  end

  defp context_source_request(base_pack, config) do
    base_pack
    |> Map.take([
      :session_id,
      :objective,
      :unresolved_questions,
      :commitments,
      :refs,
      :mode,
      :trace_id
    ])
    |> Map.merge(%{
      source_ref: config.source_ref,
      binding_key: config.binding_key,
      usage_phase: config.usage_phase,
      schema_ref: config.schema_ref,
      max_fragments: config.max_fragments
    })
  end

  defp normalize_source_fragments(fragments, config, adapter_key) do
    fragments
    |> Enum.take(config.max_fragments)
    |> Enum.map(
      &normalize_fragment!(
        &1,
        config.source_ref,
        config.binding_key,
        adapter_key,
        config.schema_ref
      )
    )
  end

  defp successful_source_report(normalized_fragments, report, config, adapter_key) do
    {status, error} = fragment_report_status(config.required?, normalized_fragments)

    %{
      report
      | adapter_key: adapter_key,
        status: status,
        fragment_count: length(normalized_fragments),
        error: error,
        fragments: normalized_fragments
    }
  end

  defp fragment_report_status(true, []), do: {:degraded, :required_fragment_missing}
  defp fragment_report_status(_required?, _fragments), do: {:ok, nil}

  defp fetch_fragments(adapter, request, runtime_binding, timeout_ms) do
    task = Task.async(fn -> adapter.fetch_fragments(request, runtime_binding) end)

    case Task.yield(task, timeout_ms) || Task.shutdown(task, :brutal_kill) do
      {:ok, {:ok, fragments}} when is_list(fragments) -> {:ok, fragments}
      {:ok, {:error, reason}} -> {:error, reason}
      {:ok, other} -> {:error, {:invalid_adapter_response, other}}
      {:exit, reason} -> {:error, {:adapter_crash, reason}}
      nil -> {:error, :timeout}
    end
  end

  defp normalize_fragment!(fragment, source_ref, binding_key, adapter_key, schema_ref) do
    fragment = normalize_fragment_attrs(fragment)

    normalized_fragment = %{
      fragment_id: fetch_value(fragment, :fragment_id),
      schema_ref: fetch_value(fragment, :schema_ref) || schema_ref,
      schema_version: fetch_value(fragment, :schema_version),
      content: fetch_value(fragment, :content),
      provenance:
        Map.merge(
          default_provenance(source_ref, binding_key, adapter_key),
          fetch_value(fragment, :provenance) || %{}
        ),
      staleness: fetch_value(fragment, :staleness) || %{class: "unspecified"},
      metadata: fetch_value(fragment, :metadata) || %{}
    }

    case ContextFragment.new(normalized_fragment) do
      {:ok, %ContextFragment{} = normalized} -> Map.from_struct(normalized)
      {:error, reason} -> raise ArgumentError, "invalid context fragment: #{inspect(reason)}"
    end
  end

  defp normalize_fragment_attrs(%ContextFragment{} = fragment), do: Map.from_struct(fragment)

  defp normalize_fragment_attrs(%{__struct__: _} = fragment),
    do: fragment |> Map.from_struct() |> normalize_fragment_attrs()

  defp normalize_fragment_attrs(fragment) when is_map(fragment),
    do: normalize_nested_maps(fragment)

  defp default_provenance(source_ref, binding_key, adapter_key) do
    %{
      "source_ref" => source_ref,
      "binding_key" => binding_key,
      "adapter_key" => adapter_key
    }
  end

  defp normalize_bindings(bindings) when is_map(bindings) do
    Map.new(bindings, fn {binding_key, binding} ->
      {to_string(binding_key), normalize_nested_maps(binding)}
    end)
  end

  defp normalize_bindings(_bindings), do: %{}

  defp normalize_nested_maps(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_map(value) ->
        {key, normalize_nested_maps(value)}

      pair ->
        pair
    end)
  end

  defp fetch_value(source, key) do
    source = normalize_fragment_attrs(source)
    Map.get(source, key) || Map.get(source, Atom.to_string(key))
  end
end
