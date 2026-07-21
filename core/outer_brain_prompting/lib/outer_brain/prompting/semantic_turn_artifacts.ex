defmodule OuterBrain.Prompting.SemanticTurnArtifacts do
  @moduledoc """
  Deterministic context, prompt-manifest, reply, and continuation artifacts for
  the first governed Synapse model turn.

  Provider-native payloads are never accepted. Prompt manifests contain pinned
  source artifact refs and ordering only; final assistant text is stored as a
  separate immutable artifact after provider normalization.
  """

  alias GroundPlane.Boundary.Codec
  alias OuterBrain.Contracts.{ReplyBodyBoundary, SemanticContextProvenance}
  alias OuterBrain.Journal.Tables.ReplyPublicationRecord
  alias OuterBrain.Prompting.ImmutableArtifact

  defmodule PromptContext do
    @moduledoc false
    @enforce_keys [
      :provenance,
      :context_artifact,
      :prompt_artifact,
      :run_ref,
      :turn_ref,
      :model_profile_ref,
      :memory_snapshot_refs
    ]
    defstruct @enforce_keys ++ [previous_semantic_ref: nil]

    @type t :: %__MODULE__{}
  end

  defmodule ReplyContinuation do
    @moduledoc false
    @enforce_keys [
      :publication,
      :reply_artifact,
      :next_provenance,
      :next_context_artifact,
      :previous_semantic_ref,
      :prompt_artifact_ref,
      :run_ref,
      :turn_ref,
      :attempt_ref,
      :published_at,
      :model_profile_ref,
      :memory_snapshot_refs
    ]
    defstruct @enforce_keys

    @type t :: %__MODULE__{}
  end

  @required_scope_fields ~w(
    tenant_ref installation_ref workspace_ref project_ref environment_ref
    authority_packet_ref permission_decision_ref idempotency_key trace_id
    correlation_id release_manifest_ref input_claim_check_ref
    output_claim_check_ref redaction_policy_ref normalizer_version run_ref
    turn_ref model_profile_ref provider_ref model_ref producing_operation_ref
  )a

  @spec prepare_prompt(map() | keyword()) :: {:ok, PromptContext.t()} | {:error, term()}
  def prepare_prompt(attrs) when is_map(attrs) or is_list(attrs) do
    attrs = Map.new(attrs)

    with :ok <- require_strings(attrs, @required_scope_fields),
         :ok <- require_actor(attrs),
         {:ok, source_artifacts} <- normalize_sources(value(attrs, :source_artifacts)),
         {:ok, memory_snapshot_refs} <- normalize_refs(value(attrs, :memory_snapshot_refs, [])),
         {:ok, access_attrs} <- access_attrs(attrs) do
      context_payload = context_payload(attrs, source_artifacts, memory_snapshot_refs)

      with {:ok, context_artifact} <-
             ImmutableArtifact.json(
               "context",
               context_payload,
               artifact_attrs(attrs, access_attrs,
                 schema_ref: "schema://outer-brain/synapse-context/v1",
                 provenance: artifact_provenance(attrs, "context", source_artifacts),
                 causal_parent_refs: Enum.map(source_artifacts, & &1["artifact_ref"])
               )
             ),
           prompt_payload <- prompt_payload(attrs, source_artifacts, context_artifact),
           {:ok, prompt_artifact} <-
             ImmutableArtifact.json(
               "prompt-manifest",
               prompt_payload,
               artifact_attrs(attrs, access_attrs,
                 schema_ref: "schema://outer-brain/synapse-prompt-manifest/v1",
                 provenance: artifact_provenance(attrs, "prompt_manifest", source_artifacts),
                 causal_parent_refs: [
                   context_artifact.descriptor.artifact_ref | target_source_refs(source_artifacts)
                 ]
               )
             ),
           {:ok, provenance} <-
             semantic_provenance(
               attrs,
               context_artifact,
               prompt_artifact,
               source_artifacts,
               memory_snapshot_refs
             ) do
        {:ok,
         %PromptContext{
           provenance: provenance,
           context_artifact: context_artifact,
           prompt_artifact: prompt_artifact,
           run_ref: value(attrs, :run_ref),
           turn_ref: value(attrs, :turn_ref),
           model_profile_ref: value(attrs, :model_profile_ref),
           memory_snapshot_refs: memory_snapshot_refs,
           previous_semantic_ref: value(attrs, :previous_semantic_ref)
         }}
      end
    end
  end

  def prepare_prompt(_attrs), do: {:error, :invalid_prompt_context}

  @spec prepare_reply(PromptContext.t(), map() | keyword()) ::
          {:ok, ReplyContinuation.t()} | {:error, term()}
  def prepare_reply(%PromptContext{} = prompt, attrs) when is_map(attrs) or is_list(attrs) do
    attrs = Map.new(attrs)

    with :ok <- require_strings(attrs, [:attempt_ref, :assistant_reply, :dedupe_key]),
         %DateTime{} = published_at <- value(attrs, :published_at),
         {:ok, access_attrs} <- access_attrs(attrs),
         {:ok, reply_artifact} <- reply_artifact(prompt, attrs, access_attrs),
         {:ok, next_context_artifact} <-
           continuation_artifact(prompt, attrs, access_attrs, reply_artifact),
         {:ok, next_provenance} <-
           continuation_provenance(prompt, attrs, reply_artifact, next_context_artifact),
         {:ok, reply_body} <-
           ReplyBodyBoundary.build(
             prompt.turn_ref,
             :final,
             value(attrs, :dedupe_key),
             value(attrs, :assistant_reply),
             tenant_scope: prompt.provenance.tenant_ref,
             existing_store_ref: reply_artifact.descriptor.location_ref,
             store_security_posture_ref: "store-security://outer-brain/postgres/v1",
             encryption_posture_ref: "encryption-posture://outer-brain/database/v1"
           ),
         {:ok, publication} <-
           ReplyPublicationRecord.new(%{
             publication_id: publication_ref(prompt, reply_artifact),
             causal_unit_id: prompt.turn_ref,
             phase: :final,
             state: :published,
             dedupe_key: value(attrs, :dedupe_key),
             body: reply_body.preview,
             body_ref: reply_body.ref
           }) do
      {:ok,
       %ReplyContinuation{
         publication: publication,
         reply_artifact: reply_artifact,
         next_provenance: next_provenance,
         next_context_artifact: next_context_artifact,
         previous_semantic_ref: prompt.provenance.semantic_ref,
         prompt_artifact_ref: prompt.prompt_artifact.descriptor.artifact_ref,
         run_ref: prompt.run_ref,
         turn_ref: prompt.turn_ref,
         attempt_ref: value(attrs, :attempt_ref),
         published_at: published_at,
         model_profile_ref: prompt.model_profile_ref,
         memory_snapshot_refs: prompt.memory_snapshot_refs
       }}
    else
      _other -> {:error, :invalid_reply_continuation}
    end
  end

  def prepare_reply(_prompt, _attrs), do: {:error, :invalid_reply_continuation}

  defp context_payload(attrs, sources, memory_snapshot_refs) do
    %{
      "schema_ref" => "schema://outer-brain/synapse-context/v1",
      "run_ref" => value(attrs, :run_ref),
      "turn_ref" => value(attrs, :turn_ref),
      "model_profile_ref" => value(attrs, :model_profile_ref),
      "provider_ref" => value(attrs, :provider_ref),
      "model_ref" => value(attrs, :model_ref),
      "source_artifacts" => sources,
      "memory_snapshot_refs" => memory_snapshot_refs,
      "redaction_policy_ref" => value(attrs, :redaction_policy_ref),
      "normalizer_version" => value(attrs, :normalizer_version)
    }
  end

  defp prompt_payload(attrs, sources, context_artifact) do
    %{
      "schema_ref" => "schema://outer-brain/synapse-prompt-manifest/v1",
      "run_ref" => value(attrs, :run_ref),
      "turn_ref" => value(attrs, :turn_ref),
      "context_artifact_ref" => context_artifact.descriptor.artifact_ref,
      "context_digest" => context_artifact.descriptor.content_digest,
      "message_artifact_refs" => target_source_refs(sources),
      "model_profile_ref" => value(attrs, :model_profile_ref),
      "provider_ref" => value(attrs, :provider_ref),
      "model_ref" => value(attrs, :model_ref)
    }
  end

  defp reply_artifact(prompt, attrs, access_attrs) do
    ImmutableArtifact.text("assistant-reply", value(attrs, :assistant_reply),
      tenant_ref: prompt.provenance.tenant_ref,
      authority_packet_ref: prompt.provenance.authority_packet_ref,
      producing_operation_ref: value(attrs, :attempt_ref),
      allowed_reader_refs: access_attrs.allowed_reader_refs,
      allowed_operation_refs: access_attrs.allowed_operation_refs,
      schema_ref: "schema://outer-brain/assistant-reply/v1",
      provenance: %{
        "run_ref" => prompt.run_ref,
        "turn_ref" => prompt.turn_ref,
        "attempt_ref" => value(attrs, :attempt_ref),
        "prompt_artifact_ref" => prompt.prompt_artifact.descriptor.artifact_ref,
        "context_artifact_ref" => prompt.context_artifact.descriptor.artifact_ref
      },
      causal_parent_refs: [
        prompt.context_artifact.descriptor.artifact_ref,
        prompt.prompt_artifact.descriptor.artifact_ref,
        value(attrs, :attempt_ref)
      ],
      retention: %{"policy_ref" => "retention://outer-brain/synapse-reply/v1"}
    )
  end

  defp continuation_artifact(prompt, attrs, access_attrs, reply_artifact) do
    payload = %{
      "schema_ref" => "schema://outer-brain/synapse-context/v1",
      "run_ref" => prompt.run_ref,
      "turn_ref" => prompt.turn_ref,
      "previous_semantic_ref" => prompt.provenance.semantic_ref,
      "previous_context_artifact_ref" => prompt.context_artifact.descriptor.artifact_ref,
      "prompt_artifact_ref" => prompt.prompt_artifact.descriptor.artifact_ref,
      "assistant_reply_artifact_ref" => reply_artifact.descriptor.artifact_ref,
      "attempt_ref" => value(attrs, :attempt_ref),
      "model_profile_ref" => prompt.model_profile_ref,
      "memory_snapshot_refs" => prompt.memory_snapshot_refs
    }

    ImmutableArtifact.json("context", payload,
      tenant_ref: prompt.provenance.tenant_ref,
      authority_packet_ref: prompt.provenance.authority_packet_ref,
      producing_operation_ref: value(attrs, :attempt_ref),
      allowed_reader_refs: access_attrs.allowed_reader_refs,
      allowed_operation_refs: access_attrs.allowed_operation_refs,
      schema_ref: "schema://outer-brain/synapse-context/v1",
      provenance: %{
        "run_ref" => prompt.run_ref,
        "turn_ref" => prompt.turn_ref,
        "attempt_ref" => value(attrs, :attempt_ref),
        "previous_semantic_ref" => prompt.provenance.semantic_ref,
        "artifact_role" => "continuation_context"
      },
      causal_parent_refs: [
        prompt.context_artifact.descriptor.artifact_ref,
        prompt.prompt_artifact.descriptor.artifact_ref,
        reply_artifact.descriptor.artifact_ref,
        value(attrs, :attempt_ref)
      ],
      retention: %{"policy_ref" => "retention://outer-brain/synapse-context/v1"}
    )
  end

  defp semantic_provenance(attrs, context, prompt, sources, memory_snapshot_refs) do
    semantic_ref = semantic_ref(value(attrs, :run_ref), value(attrs, :turn_ref), context, nil)

    SemanticContextProvenance.new(%{
      tenant_ref: value(attrs, :tenant_ref),
      installation_ref: value(attrs, :installation_ref),
      workspace_ref: value(attrs, :workspace_ref),
      project_ref: value(attrs, :project_ref),
      environment_ref: value(attrs, :environment_ref),
      resource_ref: value(attrs, :turn_ref),
      authority_packet_ref: value(attrs, :authority_packet_ref),
      permission_decision_ref: value(attrs, :permission_decision_ref),
      idempotency_key: value(attrs, :idempotency_key),
      trace_id: value(attrs, :trace_id),
      correlation_id: value(attrs, :correlation_id),
      release_manifest_ref: value(attrs, :release_manifest_ref),
      principal_ref: value(attrs, :principal_ref),
      system_actor_ref: value(attrs, :system_actor_ref),
      semantic_ref: semantic_ref,
      provider_ref: value(attrs, :provider_ref),
      model_ref: value(attrs, :model_ref),
      prompt_hash: prompt.descriptor.content_digest,
      context_hash: context.descriptor.content_digest,
      input_claim_check_ref: value(attrs, :input_claim_check_ref),
      output_claim_check_ref: value(attrs, :output_claim_check_ref),
      provenance_refs:
        Enum.uniq(
          Enum.map(sources, & &1["artifact_ref"]) ++
            memory_snapshot_refs ++
            [context.descriptor.artifact_ref, prompt.descriptor.artifact_ref]
        ),
      normalizer_version: value(attrs, :normalizer_version),
      redaction_policy_ref: value(attrs, :redaction_policy_ref)
    })
  end

  defp continuation_provenance(prompt, attrs, reply_artifact, next_context_artifact) do
    previous = prompt.provenance

    SemanticContextProvenance.new(%{
      SemanticContextProvenance.to_map(previous)
      | semantic_ref:
          semantic_ref(
            prompt.run_ref,
            prompt.turn_ref,
            next_context_artifact,
            value(attrs, :attempt_ref)
          ),
        idempotency_key: previous.idempotency_key <> ":continuation",
        context_hash: next_context_artifact.descriptor.content_digest,
        provenance_refs:
          Enum.uniq(
            previous.provenance_refs ++
              [
                previous.semantic_ref,
                reply_artifact.descriptor.artifact_ref,
                value(attrs, :attempt_ref)
              ]
          )
    })
  end

  defp semantic_ref(run_ref, turn_ref, artifact, attempt_ref) do
    Codec.digest(%{
      "run_ref" => run_ref,
      "turn_ref" => turn_ref,
      "artifact_ref" => artifact.descriptor.artifact_ref,
      "attempt_ref" => attempt_ref
    })
    |> String.replace_prefix("sha256:", "semantic://outer-brain/")
  end

  defp publication_ref(prompt, reply_artifact) do
    Codec.digest(%{
      "run_ref" => prompt.run_ref,
      "turn_ref" => prompt.turn_ref,
      "reply_artifact_ref" => reply_artifact.descriptor.artifact_ref
    })
    |> String.replace_prefix("sha256:", "publication://outer-brain/")
  end

  defp artifact_attrs(attrs, access_attrs, overrides) do
    [
      tenant_ref: value(attrs, :tenant_ref),
      authority_packet_ref: value(attrs, :authority_packet_ref),
      producing_operation_ref: value(attrs, :producing_operation_ref),
      allowed_reader_refs: access_attrs.allowed_reader_refs,
      allowed_operation_refs: access_attrs.allowed_operation_refs,
      retention: %{"policy_ref" => "retention://outer-brain/synapse-context/v1"}
    ]
    |> Keyword.merge(overrides)
  end

  defp artifact_provenance(attrs, role, sources) do
    %{
      "artifact_role" => role,
      "run_ref" => value(attrs, :run_ref),
      "turn_ref" => value(attrs, :turn_ref),
      "model_profile_ref" => value(attrs, :model_profile_ref),
      "source_artifact_refs" => Enum.map(sources, & &1["artifact_ref"]),
      "redaction_policy_ref" => value(attrs, :redaction_policy_ref),
      "normalizer_version" => value(attrs, :normalizer_version)
    }
  end

  defp target_source_refs(sources) do
    sources
    |> Enum.sort_by(&source_rank(&1["role"]))
    |> Enum.map(& &1["artifact_ref"])
  end

  defp source_rank("system_instruction"), do: 0
  defp source_rank("user_input"), do: 1
  defp source_rank(_role), do: 2

  defp normalize_sources(sources) when is_list(sources) and sources != [] do
    sources
    |> Enum.reduce_while({:ok, []}, fn source, {:ok, acc} ->
      source = Map.new(source)

      with artifact_ref when is_binary(artifact_ref) and artifact_ref != "" <-
             value(source, :artifact_ref),
           content_digest when is_binary(content_digest) <- value(source, :content_digest),
           true <- String.match?(content_digest, ~r/\Asha256:[0-9a-f]{64}\z/),
           role when is_binary(role) and role != "" <- value(source, :role) do
        normalized = %{
          "artifact_ref" => artifact_ref,
          "content_digest" => content_digest,
          "role" => role
        }

        {:cont, {:ok, [normalized | acc]}}
      else
        _other -> {:halt, {:error, :invalid_source_artifact}}
      end
    end)
    |> case do
      {:ok, normalized} -> require_prompt_sources(Enum.reverse(normalized))
      {:error, _reason} = error -> error
    end
  end

  defp normalize_sources(_sources), do: {:error, :source_artifacts_required}

  defp require_prompt_sources(sources) do
    roles = MapSet.new(sources, & &1["role"])

    if MapSet.subset?(MapSet.new(~w(system_instruction user_input)), roles),
      do: {:ok, sources},
      else: {:error, :prompt_source_artifacts_required}
  end

  defp access_attrs(attrs) do
    with {:ok, readers} <- normalize_non_empty_refs(value(attrs, :allowed_reader_refs)),
         {:ok, operations} <- normalize_non_empty_refs(value(attrs, :allowed_operation_refs)) do
      {:ok, %{allowed_reader_refs: readers, allowed_operation_refs: operations}}
    end
  end

  defp normalize_non_empty_refs(refs) when is_list(refs) and refs != [], do: normalize_refs(refs)
  defp normalize_non_empty_refs(_refs), do: {:error, :artifact_access_scope_required}

  defp normalize_refs(refs) when is_list(refs) do
    refs = Enum.uniq(refs)

    if Enum.all?(refs, &(is_binary(&1) and &1 != "")),
      do: {:ok, refs},
      else: {:error, :invalid_artifact_refs}
  end

  defp normalize_refs(_refs), do: {:error, :invalid_artifact_refs}

  defp require_strings(attrs, fields) do
    case Enum.find(fields, fn field ->
           case value(attrs, field) do
             value when is_binary(value) -> String.trim(value) == ""
             _other -> true
           end
         end) do
      nil -> :ok
      field -> {:error, {:missing_semantic_artifact_field, field}}
    end
  end

  defp require_actor(attrs) do
    case {value(attrs, :principal_ref), value(attrs, :system_actor_ref)} do
      {nil, nil} -> {:error, :semantic_actor_required}
      _other -> :ok
    end
  end

  defp value(attrs, key, default \\ nil),
    do: Map.get(attrs, key, Map.get(attrs, Atom.to_string(key), default))
end
