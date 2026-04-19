defmodule OuterBrain.Bridges.DomainSubmission do
  @moduledoc """
  Semantic-turn submission boundary over the typed `citadel_domain_surface` seam.
  """

  alias Citadel.DomainSurface, as: Domain
  alias OuterBrain.Bridges.ManifestCompiler
  alias OuterBrain.Contracts.{ActionRequest, SemanticFailure}
  alias OuterBrain.Core.{ActionRequestCompiler, SemanticFrame, TurnSelector}

  @type accepted :: %{
          required(:action_request) => ActionRequest.t(),
          required(:dispatch_result) => term(),
          required(:manifest_id) => String.t()
        }

  @spec submit_turn(String.t(), keyword()) :: {:ok, accepted()} | {:error, term()}
  def submit_turn(text, opts \\ []) when is_binary(text) do
    with {:ok, normalized} <- normalize_opts(opts) do
      submit_normalized_turn(text, normalized)
    end
  end

  defp submit_normalized_turn(text, normalized) do
    case compile_semantic_request(text, normalized) do
      {:ok, snapshot, action_request} ->
        dispatch_semantic_request(snapshot, action_request, normalized)

      {:error, reason} ->
        semantic_failure_result(reason, normalized)
    end
  end

  defp dispatch_semantic_request(snapshot, action_request, normalized) do
    with {:ok, domain_request} <-
           build_domain_request(
             normalized.domain_module,
             action_request,
             normalized.domain_request_opts
           ),
         {:ok, dispatch_result} <- Domain.route(domain_request, normalized.route_opts) do
      {:ok,
       %{
         action_request: action_request,
         dispatch_result: dispatch_result,
         manifest_id: snapshot.manifest_id
       }}
    else
      {:error, reason} -> semantic_failure_result(reason, normalized)
    end
  end

  defp compile_semantic_request(text, normalized) do
    with {:ok, snapshot} <- ManifestCompiler.compile_domain_routes(normalized.route_sources),
         {:ok, selection, confidence} <-
           TurnSelector.select(snapshot, text,
             request_id: normalized.request_id,
             route: normalized.route,
             scope_id: normalized.scope_id,
             workspace_id: normalized.workspace_id,
             workspace_root: normalized.workspace_root
           ),
         {:ok, action_request} <-
           compile_action_request(normalized.session_id, text, snapshot, selection, confidence) do
      {:ok, snapshot, action_request}
    end
  end

  defp compile_action_request(session_id, text, snapshot, selection, confidence) do
    frame = SemanticFrame.seed(session_id, text)
    ActionRequestCompiler.compile(frame, snapshot, selection, confidence)
  end

  defp build_domain_request(domain_module, %ActionRequest{} = request, domain_request_opts) do
    route_name = String.to_existing_atom(request.route)

    Code.ensure_loaded!(domain_module)

    if function_exported?(domain_module, route_name, 2) do
      apply(domain_module, route_name, [request.args, domain_request_opts])
    else
      {:error, {:unknown_domain_route, domain_module, route_name}}
    end
  rescue
    _error in ArgumentError ->
      {:error, {:unknown_domain_route, domain_module, request.route}}
  end

  defp normalize_opts(opts) when is_list(opts) do
    with {:ok, session_id} <- required_string(opts, :session_id),
         {:ok, request_id} <- required_string(opts, :idempotency_key),
         {:ok, domain_module} <- required_atom(opts, :domain_module),
         {:ok, route_sources} <- required_route_sources(opts),
         {:ok, trace_id} <- required_string(opts, :trace_id) do
      context =
        %{
          session_id: session_id,
          tenant_id: Keyword.get(opts, :tenant_id),
          actor_id: Keyword.get(opts, :actor_id),
          environment: Keyword.get(opts, :environment),
          scope_id: Keyword.get(opts, :scope_id)
        }
        |> Enum.reject(fn {_key, value} -> is_nil(value) end)
        |> Map.new()
        |> Map.merge(Keyword.get(opts, :context, %{}))

      metadata =
        opts
        |> Keyword.get(:metadata, %{})
        |> Map.new()
        |> Map.put_new(:semantic_runtime, :outer_brain)

      {:ok,
       %{
         session_id: session_id,
         request_id: request_id,
         domain_module: domain_module,
         route_sources: route_sources,
         route: Keyword.get(opts, :route),
         scope_id: Keyword.get(opts, :scope_id),
         workspace_id: Keyword.get(opts, :workspace_id),
         workspace_root: Keyword.get(opts, :workspace_root),
         domain_request_opts:
           [
             idempotency_key: request_id,
             trace_id: trace_id,
             context: context,
             metadata: metadata
           ] ++ Keyword.get(opts, :domain_request_opts, []),
         route_opts:
           Keyword.take(opts, [:kernel_runtime, :external_integration]) ++
             Keyword.get(opts, :route_opts, []),
         tenant_id: Keyword.get(opts, :tenant_id),
         trace_id: trace_id
       }}
    end
  end

  defp semantic_failure_result(reason, normalized) do
    kind = semantic_failure_kind(reason)

    SemanticFailure.new(%{
      kind: kind,
      tenant_id: normalized.tenant_id || "unknown-tenant",
      semantic_session_id: normalized.session_id,
      causal_unit_id: normalized.request_id,
      request_trace_id: normalized.trace_id,
      provenance: [%{"surface" => "outer_brain.domain_submission"}],
      operator_message: semantic_failure_message(kind, reason)
    })
    |> case do
      {:ok, failure} -> {:error, {:semantic_failure, failure}}
      {:error, failure_reason} -> {:error, failure_reason}
    end
  end

  defp semantic_failure_kind(:clarification_required), do: :semantic_insufficient_context
  defp semantic_failure_kind(:route_not_present), do: :semantic_tool_mismatch
  defp semantic_failure_kind(:stale_manifest), do: :semantic_context_stale
  defp semantic_failure_kind(:blank_turn), do: :semantic_invalid_output

  defp semantic_failure_kind({:unknown_domain_route, _module, _route}),
    do: :semantic_tool_mismatch

  defp semantic_failure_kind(_reason), do: :semantic_invalid_output

  defp semantic_failure_message(:semantic_insufficient_context, _reason) do
    "The semantic runtime needs clarification before it can select a deterministic route."
  end

  defp semantic_failure_message(:semantic_tool_mismatch, _reason) do
    "The semantic runtime selected a route that is not available in the manifest."
  end

  defp semantic_failure_message(:semantic_context_stale, _reason) do
    "The semantic runtime observed stale manifest or context data."
  end

  defp semantic_failure_message(:semantic_invalid_output, reason) do
    "The semantic runtime produced invalid deterministic output: #{inspect(reason)}."
  end

  defp required_string(opts, key) do
    case Keyword.get(opts, key) do
      value when is_binary(value) and value != "" -> {:ok, value}
      _other -> {:error, {:missing_option, key}}
    end
  end

  defp required_atom(opts, key) do
    case Keyword.get(opts, key) do
      value when is_atom(value) -> {:ok, value}
      _other -> {:error, {:missing_option, key}}
    end
  end

  defp required_route_sources(opts) do
    case Keyword.get(opts, :route_sources) do
      value when is_list(value) and value != [] -> {:ok, value}
      _other -> {:error, {:missing_option, :route_sources}}
    end
  end
end
