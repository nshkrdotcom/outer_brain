defmodule OuterBrain.Memory.ShareUpClient do
  @moduledoc """
  Coordinates private-to-shared memory transitions through owner callbacks.

  The client owns sequencing and local fail-closed checks while Mezzanine and
  the tier store remain injected owner seams.
  """

  @required_request_fields [
    :tenant_ref,
    :user_ref,
    :agent_ref,
    :trace_id,
    :snapshot_epoch,
    :target_scope_ref,
    :private_fragment,
    :source_node_ref,
    :commit_lsn,
    :commit_hlc
  ]

  @type callback_opts :: keyword()
  @type share_up_result :: %{shared_fragment: map(), proof_token: map()}

  @spec share_up(map(), callback_opts()) :: {:ok, share_up_result()} | {:error, term()}
  def share_up(request, opts \\ [])

  def share_up(request, opts) when is_map(request) and is_list(opts) do
    with :ok <- require_request_fields(request),
         :ok <- authorize_private_owner(request),
         context = base_context(request),
         {:ok, true} <- scope_registered(context, opts),
         {:ok, share_up_policy} <- call(opts, :share_up_policy, [context]),
         {:ok, transform_pipeline, non_identity_count} <-
           non_identity_pipeline(share_up_policy),
         context =
           context
           |> Map.put(:share_up_policy, share_up_policy)
           |> Map.put(:transform_pipeline, transform_pipeline)
           |> Map.put(:non_identity_transform_count, non_identity_count),
         {:ok, transformed_fragment} <-
           call(opts, :transform, [request.private_fragment, context], &identity_transform/2),
         shared_fragment = seal_shared_fragment(transformed_fragment, context),
         {:ok, inserted_fragment} <- call(opts, :insert_shared, [shared_fragment, context]),
         proof_context = Map.put(context, :shared_fragment, inserted_fragment),
         {:ok, proof_token} <- call(opts, :proof_emitter, [proof_context]) do
      {:ok, %{shared_fragment: inserted_fragment, proof_token: proof_token}}
    else
      {:ok, false} ->
        {:error, {:unregistered_shared_scope, string_value(request, :target_scope_ref)}}

      error ->
        error
    end
  end

  def share_up(_request, _opts), do: {:error, :invalid_share_up_request}

  defp scope_registered(context, opts) do
    call(opts, :scope_registered?, [context])
  end

  defp seal_shared_fragment(fragment, context) do
    request = context.request
    policy_ref = policy_ref(context.share_up_policy)
    content = fetch_value(fragment, :content) || fetch_value(request.private_fragment, :content)
    effective_access = effective_access(context)

    %{
      fragment_id: shared_fragment_id(request, policy_ref),
      tier: :shared,
      tenant_ref: request.tenant_ref,
      scope_ref: request.target_scope_ref,
      parent_fragment_id: string_value(request.private_fragment, :fragment_id),
      source_node_ref: request.source_node_ref,
      t_epoch: request.snapshot_epoch,
      source_agents: list_value(request.private_fragment, :source_agents),
      source_resources: list_value(request.private_fragment, :source_resources),
      source_scopes: list_value(request.private_fragment, :source_scopes),
      access_agents: Map.get(effective_access, :agent_refs, []),
      access_resources: Map.get(effective_access, :resource_refs, []),
      access_scopes: Map.get(effective_access, :scope_refs, []),
      access_projection_hash: access_projection_hash(request, context, effective_access),
      applied_policies: [policy_ref],
      evidence_refs: list_value(request.private_fragment, :evidence_refs),
      governance_refs: [],
      content: content,
      content_hash: content_hash(content),
      content_ref:
        fetch_value(fragment, :content_ref) || fetch_value(request.private_fragment, :content_ref),
      schema_ref:
        string_value(fragment, :schema_ref) || string_value(request.private_fragment, :schema_ref),
      share_up_policy_ref: policy_ref,
      transform_pipeline: context.transform_pipeline,
      non_identity_transform_count: context.non_identity_transform_count,
      metadata: map_value(request.private_fragment, :metadata),
      provenance: %{
        source_lineage: %{
          user_ref: request.user_ref,
          parent_fragment_id: string_value(request.private_fragment, :fragment_id),
          source_agents: list_value(request.private_fragment, :source_agents),
          source_resources: list_value(request.private_fragment, :source_resources),
          source_scopes: list_value(request.private_fragment, :source_scopes)
        },
        parent_source_node_ref: string_value(request.private_fragment, :source_node_ref),
        effective_access: effective_access,
        source_node_ref: request.source_node_ref,
        commit_lsn: request.commit_lsn,
        commit_hlc: request.commit_hlc,
        snapshot_epoch: request.snapshot_epoch,
        trace_id: request.trace_id,
        share_up_policy_ref: policy_ref
      }
    }
  end

  defp effective_access(context) do
    private_fragment = context.request.private_fragment

    %{
      agent_refs: list_value(private_fragment, :access_agents),
      resource_refs: list_value(private_fragment, :access_resources),
      scope_refs: [context.request.target_scope_ref]
    }
  end

  defp require_request_fields(request) do
    case Enum.find(@required_request_fields, &missing_request_field?(request, &1)) do
      nil ->
        :ok

      field when field in [:source_node_ref, :commit_lsn, :commit_hlc] ->
        {:error, {:missing_ordering_evidence, field}}

      field ->
        {:error, {:missing_field, field}}
    end
  end

  defp missing_request_field?(request, :snapshot_epoch) do
    not match?(epoch when is_integer(epoch) and epoch > 0, fetch_value(request, :snapshot_epoch))
  end

  defp missing_request_field?(request, :private_fragment),
    do: not is_map(fetch_value(request, :private_fragment))

  defp missing_request_field?(request, :commit_hlc), do: is_nil(fetch_value(request, :commit_hlc))

  defp missing_request_field?(request, field) do
    case string_value(request, field) do
      nil -> true
      _value -> false
    end
  end

  defp authorize_private_owner(request) do
    private_user_ref = string_value(request.private_fragment, :user_ref)

    if private_user_ref == request.user_ref do
      :ok
    else
      {:error, {:unauthorized_user, request.user_ref}}
    end
  end

  defp non_identity_pipeline(policy) do
    pipeline = pipeline(policy)
    non_identity_count = Enum.count(pipeline, &(not identity_step?(&1)))
    policy_ref = policy_ref(policy)

    cond do
      pipeline == [] ->
        {:error, {:identity_share_up_rejected, policy_ref}}

      non_identity_count == 0 ->
        {:error, {:identity_share_up_rejected, policy_ref}}

      true ->
        {:ok, pipeline, non_identity_count}
    end
  end

  defp pipeline(policy) do
    fetch_value(policy, :transform_pipeline) ||
      fetch_value(policy, :pipeline) ||
      policy |> map_value(:spec) |> fetch_value(:pipeline) ||
      []
  end

  defp identity_step?(step) when is_map(step) do
    step
    |> fetch_value(:kind)
    |> case do
      value when is_atom(value) ->
        value == :identity

      value when is_binary(value) ->
        String.downcase(value) in ["identity", "transform://identity"]

      _other ->
        false
    end
  end

  defp identity_step?(_step), do: false

  defp policy_ref(policy) do
    string_value(policy, :policy_ref) ||
      string_value(policy, :share_up_policy_ref) ||
      string_value(policy, :policy_id) ||
      "share-up-policy://unknown"
  end

  defp base_context(request) do
    %{
      request: request,
      tenant_ref: request.tenant_ref,
      user_ref: request.user_ref,
      agent_ref: request.agent_ref,
      target_scope_ref: request.target_scope_ref,
      snapshot_epoch: request.snapshot_epoch,
      trace_id: request.trace_id
    }
  end

  defp call(opts, key, args, default \\ nil) do
    case Keyword.get(opts, key) do
      fun when is_function(fun, length(args)) -> apply(fun, args)
      nil when is_function(default, length(args)) -> apply(default, args)
      nil -> {:error, {:missing_callback, key}}
      _other -> {:error, {:invalid_callback, key}}
    end
  end

  defp identity_transform(fragment, _context), do: {:ok, fragment}

  defp shared_fragment_id(request, policy_ref) do
    seed =
      [
        request.tenant_ref,
        request.target_scope_ref,
        request.private_fragment.fragment_id,
        policy_ref
      ]
      |> Enum.join("|")

    "shared:" <> Base.encode16(:crypto.hash(:sha256, seed), case: :lower)
  end

  defp content_hash(content) do
    "sha256:" <>
      Base.encode16(:crypto.hash(:sha256, :erlang.term_to_binary(content)), case: :lower)
  end

  defp access_projection_hash(request, context, effective_access) do
    payload = %{
      source: %{
        agents: list_value(request.private_fragment, :source_agents),
        resources: list_value(request.private_fragment, :source_resources),
        scopes: list_value(request.private_fragment, :source_scopes)
      },
      effective: effective_access,
      pipeline: context.transform_pipeline,
      policy_ref: policy_ref(context.share_up_policy)
    }

    "sha256:" <>
      Base.encode16(:crypto.hash(:sha256, :erlang.term_to_binary(payload)), case: :lower)
  end

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
