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

    Map.merge(base_pack, %{
      fragments: Enum.flat_map(reports, & &1.fragments),
      context_sources: Enum.map(reports, &Map.delete(&1, :fragments))
    })
  end

  defp fetch_source_report(base_pack, source, context_bindings, opts) do
    source_ref = fetch_value(source, :source_ref)
    binding_key = fetch_value(source, :binding_key)
    usage_phase = fetch_value(source, :usage_phase)
    required? = fetch_value(source, :required?) || false
    schema_ref = fetch_value(source, :schema_ref)
    max_fragments = fetch_value(source, :max_fragments) || 5
    merge_strategy = fetch_value(source, :merge_strategy) || :append
    runtime_binding = Map.get(context_bindings, binding_key)

    report = %{
      source_ref: source_ref,
      binding_key: binding_key,
      usage_phase: usage_phase,
      required?: required?,
      schema_ref: schema_ref,
      merge_strategy: merge_strategy,
      status: :degraded,
      adapter_key: nil,
      fragment_count: 0,
      error: nil,
      fragments: []
    }

    cond do
      is_nil(base_pack.trace_id) ->
        %{report | error: :missing_trace_id}

      not is_map(runtime_binding) ->
        %{report | error: :binding_not_found}

      true ->
        adapter_key = fetch_value(runtime_binding, :adapter_key)

        timeout_ms =
          fetch_value(runtime_binding, :timeout_ms) || fetch_value(source, :timeout_ms) || 1_000

        case ContextAdapterRegistry.resolve(runtime_binding, opts) do
          {:ok, adapter} ->
            request =
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
                source_ref: source_ref,
                binding_key: binding_key,
                usage_phase: usage_phase,
                schema_ref: schema_ref,
                max_fragments: max_fragments
              })

            case fetch_fragments(adapter, request, runtime_binding, timeout_ms) do
              {:ok, fragments} ->
                normalized_fragments =
                  fragments
                  |> Enum.take(max_fragments)
                  |> Enum.map(
                    &normalize_fragment!(&1, source_ref, binding_key, adapter_key, schema_ref)
                  )

                %{
                  report
                  | adapter_key: adapter_key,
                    status:
                      if(required? and normalized_fragments == [], do: :degraded, else: :ok),
                    fragment_count: length(normalized_fragments),
                    error:
                      if(required? and normalized_fragments == [],
                        do: :required_fragment_missing,
                        else: nil
                      ),
                    fragments: normalized_fragments
                }

              {:error, reason} ->
                %{report | adapter_key: adapter_key, error: reason}
            end

          {:error, reason} ->
            %{report | adapter_key: adapter_key, error: reason}
        end
    end
  end

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
