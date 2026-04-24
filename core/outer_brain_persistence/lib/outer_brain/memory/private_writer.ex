defmodule OuterBrain.Memory.PrivateWriter do
  @moduledoc """
  Coordinates private-memory writes with immutable provenance and proof emission.

  The persistence adapter is injected so this package can own write sequencing
  without hard-coding a specific table module into the contract tests.
  """

  @required_request_fields [
    :tenant_ref,
    :user_ref,
    :agent_ref,
    :trace_id,
    :semantic_output_ref,
    :source_node_ref,
    :commit_lsn,
    :commit_hlc,
    :effective_access
  ]

  @type callback_opts :: keyword()
  @type write_result :: %{inserted_fragments: [map()], proof_token: map()}

  @spec write_private(map(), callback_opts()) :: {:ok, write_result()} | {:error, term()}
  def write_private(request, opts \\ [])

  def write_private(request, opts) when is_map(request) and is_list(opts) do
    with :ok <- require_request_fields(request),
         context = %{request: request},
         {:ok, write_policy} <- call(opts, :write_policy, [context], &default_write_policy/1),
         context = Map.put(context, :write_policy, write_policy),
         {:ok, candidates} <- call(opts, :extract_candidates, [context], &default_candidates/1),
         {:ok, transformed} <-
           call(opts, :transform, [candidates, context], &identity_transform/2),
         sealed <- Enum.map(transformed, &seal_private_fragment(&1, context)),
         {:ok, unique_fragments} <- call(opts, :dedupe, [sealed, context], &identity_dedupe/2),
         {:ok, inserted_fragments} <- insert_fragments(unique_fragments, context, opts),
         proof_context = Map.put(context, :inserted_fragments, inserted_fragments),
         {:ok, proof_token} <- call(opts, :proof_emitter, [proof_context]) do
      {:ok, %{inserted_fragments: inserted_fragments, proof_token: proof_token}}
    end
  end

  def write_private(_request, _opts), do: {:error, :invalid_private_write_request}

  defp insert_fragments(fragments, context, opts) do
    Enum.reduce_while(fragments, {:ok, []}, fn fragment, {:ok, acc} ->
      case call(opts, :insert_private, [fragment, context]) do
        {:ok, inserted} -> {:cont, {:ok, [inserted | acc]}}
        {:error, reason} -> {:halt, {:error, reason}}
      end
    end)
    |> case do
      {:ok, inserted} -> {:ok, Enum.reverse(inserted)}
      error -> error
    end
  end

  defp seal_private_fragment(candidate, context) do
    request = context.request
    write_policy = context.write_policy
    candidate_id = fetch_value(candidate, :candidate_id) || fetch_value(candidate, :fragment_id)

    %{
      fragment_id: candidate_id,
      candidate_id: candidate_id,
      tier: :private,
      tenant_ref: request.tenant_ref,
      user_ref: request.user_ref,
      agent_ref: request.agent_ref,
      trace_id: request.trace_id,
      content: fetch_value(candidate, :content),
      metadata: map_value(candidate, :metadata),
      provenance: %{
        source_lineage: map_value(candidate, :source_lineage),
        effective_access: request.effective_access,
        source_node_ref: request.source_node_ref,
        commit_lsn: request.commit_lsn,
        commit_hlc: request.commit_hlc,
        trace_id: request.trace_id,
        write_policy_ref: fetch_value(write_policy, :policy_ref),
        semantic_output_ref: request.semantic_output_ref
      }
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

  defp missing_request_field?(request, :effective_access) do
    not is_map(fetch_value(request, :effective_access))
  end

  defp missing_request_field?(request, :commit_hlc), do: is_nil(fetch_value(request, :commit_hlc))

  defp missing_request_field?(request, field) do
    case fetch_value(request, field) do
      value when is_binary(value) and value != "" -> false
      _other -> true
    end
  end

  defp call(opts, key, args, default \\ nil) do
    case Keyword.get(opts, key) do
      fun when is_function(fun, length(args)) -> apply(fun, args)
      nil when is_function(default, length(args)) -> apply(default, args)
      nil -> {:error, {:missing_callback, key}}
      _other -> {:error, {:invalid_callback, key}}
    end
  end

  defp default_write_policy(_context),
    do: {:ok, %{policy_ref: nil, transform_policy: nil, degraded_behavior: :fail_closed}}

  defp default_candidates(%{request: request}) do
    {:ok,
     [
       %{
         candidate_id: deterministic_candidate_id(request),
         content: fetch_value(request, :semantic_output),
         source_lineage: %{semantic_output_ref: request.semantic_output_ref}
       }
     ]}
  end

  defp deterministic_candidate_id(request),
    do:
      "private:" <>
        Base.encode16(:crypto.hash(:sha256, request.semantic_output_ref), case: :lower)

  defp identity_transform(candidates, _context), do: {:ok, candidates}
  defp identity_dedupe(candidates, _context), do: {:ok, candidates}

  defp map_value(source, key) do
    case fetch_value(source, key) do
      value when is_map(value) -> value
      _other -> %{}
    end
  end

  defp fetch_value(%{__struct__: _} = source, key),
    do: source |> Map.from_struct() |> fetch_value(key)

  defp fetch_value(source, key) when is_map(source),
    do: Map.get(source, key) || Map.get(source, Atom.to_string(key))

  defp fetch_value(_source, _key), do: nil
end
