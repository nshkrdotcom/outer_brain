defmodule OuterBrain.Memory.RecallOrchestrator do
  @moduledoc """
  Coordinates epoch-pinned three-tier memory recall for OuterBrain.

  Runtime owners inject the access graph, policy registry, tier readers,
  transform executor, and proof-token emitter. This module owns the ordering of
  those calls and the local admission rules that keep one recall bound to one
  snapshot epoch.
  """

  @tiers [:private, :shared, :governed]
  @required_request_fields [:tenant_ref, :user_ref, :agent_ref, :trace_id, :source_node_ref]
  @required_ordering_fields [:snapshot_epoch, :source_node_ref, :commit_lsn, :commit_hlc]

  @type callback_opts :: keyword()
  @type recall_result :: %{
          snapshot_epoch: pos_integer(),
          admitted_fragments: [map()],
          context_pack_fragments: [map()],
          proof_token: map()
        }

  @spec recall(map(), callback_opts()) :: {:ok, recall_result()} | {:error, term()}
  def recall(request, opts \\ [])

  def recall(request, opts) when is_map(request) and is_list(opts) do
    with :ok <- require_request_fields(request),
         {:ok, snapshot} <- call(opts, :snapshot_pin, [request]),
         {:ok, ordering} <- normalize_ordering(snapshot),
         context = base_context(request, ordering),
         {:ok, access_graph} <- call(opts, :access_graph_views, [context]),
         context = Map.put(context, :access_graph, access_graph),
         :ok <- authorize_agent(context) do
      resolve_and_recall(context, opts)
    end
  end

  def recall(_request, _opts), do: {:error, :invalid_recall_request}

  defp resolve_and_recall(context, opts) do
    case call(opts, :read_policy, [context], &default_read_policy/1) do
      {:ok, read_policy} ->
        context
        |> Map.put(:read_policy, read_policy)
        |> recall_with_policy(opts)

      {:error, {:degraded, :fail_empty, reason}} ->
        emit_empty_degraded_recall(context, reason, opts)

      {:error, {:degraded, :fail_partial, reason}} ->
        context
        |> Map.put(:read_policy, %{
          policy_ref: nil,
          transform_policy: nil,
          degraded_behavior: :fail_partial,
          degraded_reason: reason
        })
        |> recall_with_policy(opts)

      {:error, {:degraded, :fail_closed, reason}} ->
        {:error, {:policy_degraded, reason}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp recall_with_policy(context, opts) do
    with {:ok, tier_fragments} <- fetch_tier_fragments(context, opts),
         admitted_fragments <- admit_fragments(tier_fragments, context),
         {:ok, transformed_fragments} <-
           call(opts, :transform, [admitted_fragments, context], &identity_transform/2),
         proof_context <-
           context
           |> Map.put(:tier_fragments, tier_fragments)
           |> Map.put(:admitted_fragments, admitted_fragments)
           |> Map.put(:transformed_fragments, transformed_fragments)
           |> Map.put(:outcome, :admitted),
         {:ok, proof_token} <- call(opts, :proof_emitter, [proof_context]) do
      {:ok,
       %{
         snapshot_epoch: context.snapshot_epoch,
         admitted_fragments: admitted_fragments,
         context_pack_fragments: transformed_fragments,
         proof_token: proof_token
       }}
    end
  end

  defp emit_empty_degraded_recall(context, reason, opts) do
    proof_context =
      context
      |> Map.put(:read_policy, nil)
      |> Map.put(:tier_fragments, %{private: [], shared: [], governed: []})
      |> Map.put(:admitted_fragments, [])
      |> Map.put(:transformed_fragments, [])
      |> Map.put(:outcome, :fail_empty)
      |> Map.put(:degraded_reason, reason)

    with {:ok, proof_token} <- call(opts, :proof_emitter, [proof_context]) do
      {:ok,
       %{
         snapshot_epoch: context.snapshot_epoch,
         admitted_fragments: [],
         context_pack_fragments: [],
         proof_token: proof_token
       }}
    end
  end

  defp fetch_tier_fragments(context, opts) do
    Enum.reduce_while(@tiers, {:ok, %{}}, fn tier, {:ok, acc} ->
      case call(opts, :tier_reader, [tier, context], &empty_tier/2) do
        {:ok, fragments} when is_list(fragments) -> {:cont, {:ok, Map.put(acc, tier, fragments)}}
        {:ok, other} -> {:halt, {:error, {:invalid_tier_reader_response, tier, other}}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
  end

  defp admit_fragments(tier_fragments, context) do
    Enum.flat_map(@tiers, fn tier ->
      tier_fragments
      |> Map.get(tier, [])
      |> Enum.filter(&accessible?(&1, tier, context))
      |> Enum.sort_by(&score/1, :desc)
      |> Enum.take(top_k(context.request, tier))
    end)
  end

  defp accessible?(fragment, :private, context) do
    request = context.request

    string_value(fragment, :user_ref) == request.user_ref and
      allows_ref?(fragment, :user_refs, request.user_ref) and
      allows_ref?(fragment, :agent_refs, request.agent_ref)
  end

  defp accessible?(fragment, :shared, context) do
    request = context.request
    graph_scopes = list_value(context.access_graph, :shared_scope_refs)
    fragment_scopes = list_value(fragment, :scope_refs)

    intersects?(fragment_scopes, graph_scopes) and
      allows_ref?(fragment, :agent_refs, request.agent_ref)
  end

  defp accessible?(fragment, :governed, context) do
    request = context.request
    access = map_value(fragment, :access)

    governed_valid? =
      Map.get(access, :governance_valid?, Map.get(access, "governance_valid?", true))

    governed_policy_refs = list_value(context.access_graph, :governed_policy_refs)
    promote_policy_ref = string_value(fragment, :promote_policy_ref)

    allows_ref?(fragment, :agent_refs, request.agent_ref) and governed_valid? != false and
      (governed_policy_refs == [] or promote_policy_ref in governed_policy_refs)
  end

  defp authorize_agent(context) do
    authorized = list_value(context.access_graph, :authorized_agent_refs)

    if context.request.agent_ref in authorized do
      :ok
    else
      {:error, {:unauthorized_agent, context.request.agent_ref}}
    end
  end

  defp require_request_fields(request) do
    case Enum.find(@required_request_fields, &(string_value(request, &1) == nil)) do
      nil -> :ok
      field -> {:error, {:missing_field, field}}
    end
  end

  defp normalize_ordering(snapshot) do
    case Enum.find(@required_ordering_fields, &missing_ordering_field?(snapshot, &1)) do
      nil ->
        {:ok,
         %{
           snapshot_epoch: fetch_value(snapshot, :snapshot_epoch),
           pinned_at: fetch_value(snapshot, :pinned_at),
           source_node_ref: string_value(snapshot, :source_node_ref),
           commit_lsn: string_value(snapshot, :commit_lsn),
           commit_hlc: fetch_value(snapshot, :commit_hlc)
         }}

      field ->
        {:error, {:missing_ordering_evidence, field}}
    end
  end

  defp missing_ordering_field?(snapshot, :snapshot_epoch) do
    not match?(epoch when is_integer(epoch) and epoch > 0, fetch_value(snapshot, :snapshot_epoch))
  end

  defp missing_ordering_field?(snapshot, field) when field in [:source_node_ref, :commit_lsn],
    do: is_nil(string_value(snapshot, field))

  defp missing_ordering_field?(snapshot, field), do: is_nil(fetch_value(snapshot, field))

  defp base_context(request, ordering) do
    Map.merge(ordering, %{
      request: request,
      tenant_ref: request.tenant_ref,
      user_ref: request.user_ref,
      agent_ref: request.agent_ref,
      trace_id: request.trace_id
    })
  end

  defp call(opts, key, args, default \\ nil) do
    case Keyword.get(opts, key) do
      fun when is_function(fun, length(args)) -> apply(fun, args)
      nil when is_function(default, length(args)) -> apply(default, args)
      nil -> {:error, {:missing_callback, key}}
      _other -> {:error, {:invalid_callback, key}}
    end
  end

  defp default_read_policy(_context),
    do: {:ok, %{policy_ref: nil, transform_policy: nil, degraded_behavior: :fail_closed}}

  defp empty_tier(_tier, _context), do: {:ok, []}
  defp identity_transform(fragments, _context), do: {:ok, fragments}

  defp allows_ref?(fragment, key, ref) do
    allowed = access_list(fragment, key)
    allowed == [] or ref in allowed
  end

  defp access_list(fragment, key) do
    access = map_value(fragment, :access)

    case list_value(access, key) do
      [] -> list_value(fragment, key)
      values -> values
    end
  end

  defp top_k(request, tier) do
    top_k_by_tier = map_value(request, :top_k_by_tier)
    fetch_value(top_k_by_tier, tier) || fetch_value(request, :top_k) || 5
  end

  defp score(fragment) do
    case fetch_value(fragment, :score) do
      score when is_number(score) -> score
      _other -> 0
    end
  end

  defp intersects?(left, right),
    do: MapSet.disjoint?(MapSet.new(left), MapSet.new(right)) == false

  defp list_value(source, key) do
    case fetch_value(source, key) do
      values when is_list(values) -> values
      nil -> []
      value -> [value]
    end
  end

  defp map_value(source, key) do
    case fetch_value(source, key) do
      value when is_map(value) -> value
      _other -> %{}
    end
  end

  defp string_value(source, key) do
    case fetch_value(source, key) do
      value when is_binary(value) and value != "" -> value
      _other -> nil
    end
  end

  defp fetch_value(%{__struct__: _} = source, key),
    do: source |> Map.from_struct() |> fetch_value(key)

  defp fetch_value(source, key) when is_map(source),
    do: Map.get(source, key) || Map.get(source, Atom.to_string(key))

  defp fetch_value(_source, _key), do: nil
end
