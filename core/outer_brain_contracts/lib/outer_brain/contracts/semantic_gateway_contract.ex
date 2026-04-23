defmodule OuterBrain.Contracts.SemanticGatewayContract do
  @moduledoc """
  Phase 6 semantic gateway owner contract.

  This module aggregates the existing OuterBrain semantic contracts into the
  M7 proof shape. It does not replace the lower execution owner and does not
  treat provider SDK fixtures as semantic durability evidence.
  """

  alias OuterBrain.Contracts.{
    ContextAdapterReadOnly,
    Phase4SemanticContract,
    PrivacyRedactionFixture,
    ReplyBodyBoundary,
    ReplyPublication,
    SemanticContextProvenance,
    SemanticDuplicateSuppression,
    SemanticFailure,
    SuppressionVisibility
  }

  @contract_id "SemanticGatewayContract.v1"
  @required_fields [
    :semantic_context_provenance_ref,
    :semantic_failure_ref,
    :read_only_context_adapter_boundary_ref,
    :reply_publication_dedupe_ref,
    :suppression_visibility_ref,
    :privacy_redaction_fixture_ref,
    :restart_replay_with_semantic_state_ref
  ]
  @forbidden [
    :raw_prompt_or_provider_body_in_evidence,
    :raw_context_pack_in_evidence,
    :provider_sdk_local_mock_as_semantic_gateway_proof,
    :lower_runtime_only_proof_without_outer_brain_owner_evidence,
    :hidden_duplicate_suppression
  ]

  @required_fixture_fields [
    :semantic_context_provenance,
    :semantic_failure,
    :context_adapter_read_only,
    :reply_publication,
    :duplicate_suppression,
    :suppression_visibility,
    :privacy_redaction_fixture,
    :restart_replay_with_semantic_state_ref
  ]

  @spec contract() :: map()
  def contract do
    %{
      id: @contract_id,
      owner: "outer_brain",
      primary_repos: ["outer_brain", "stack_lab"],
      purpose:
        "OuterBrain semantic hop boundary, context provenance, semantic failure, reply-publication dedupe, suppression visibility, privacy redaction, and restart/replay evidence for service-mode claims.",
      phase6_milestone: "M7",
      prelim_residual_ref: "P5P-002",
      required_fields: @required_fields,
      forbidden: @forbidden
    }
  end

  @spec fixture() :: map()
  def fixture do
    scope = scope_attrs()

    %{
      owner_surface_ref: "outer-brain://semantic-gateway/phase6-m7",
      real_outer_brain_surface?: true,
      lower_runtime_only_proof?: false,
      provider_sdk_mock_proof?: false,
      raw_payload_included?: false,
      raw_payload_scan_ref: "scan:phase6-m7-raw-payload-clean",
      restart_replay_with_semantic_state_ref:
        "outer-brain-restart://phase6-m7/session/semantic-state-replayed",
      semantic_context_provenance:
        Map.merge(scope, %{
          system_actor_ref: "system:outer-brain",
          resource_ref: "semantic-context:phase6-m7",
          idempotency_key: "semantic-context:phase6-m7",
          trace_id: "trace-semantic-phase6-m7",
          correlation_id: "correlation-semantic-phase6-m7",
          semantic_ref: "semantic:result-phase6-m7",
          provider_ref: "provider:semantic-host",
          model_ref: "model:phase6-semantic",
          prompt_hash: "sha256:prompt-phase6-m7",
          context_hash: "sha256:context-phase6-m7",
          input_claim_check_ref: "claim:semantic-input-phase6-m7",
          output_claim_check_ref: "claim:semantic-output-phase6-m7",
          provenance_refs: ["provenance:context-adapter-phase6-m7"],
          normalizer_version: "outer-brain-normalizer@phase6-m7",
          redaction_policy_ref: "redaction:semantic-public-v1"
        }),
      semantic_failure: %{
        kind: :semantic_insufficient_context,
        tenant_id: "tenant-phase6-m7",
        semantic_session_id: "semantic-session-phase6-m7",
        causal_unit_id: "causal-phase6-m7",
        request_trace_id: "trace-semantic-phase6-m7",
        substrate_trace_id: "outer-brain-substrate-phase6-m7",
        provenance: [%{"surface" => "outer_brain.semantic_gateway"}],
        context_hash: "sha256:context-phase6-m7",
        canonical_idempotency_key: "semantic-gateway:phase6-m7",
        operator_message: "The semantic gateway needs additional context before dispatch."
      },
      context_adapter_read_only:
        Map.merge(scope, %{
          system_actor_ref: "system:outer-brain",
          resource_ref: "context-adapter:phase6-m7",
          idempotency_key: "context-adapter:phase6-m7",
          trace_id: "trace-adapter-phase6-m7",
          correlation_id: "correlation-adapter-phase6-m7",
          adapter_ref: "context-adapter:phase6-m7",
          allowed_read_resources: ["workspace:phase6-m7", "project:semantic-runtime"],
          denied_write_resources: ["workspace:phase6-m7", "lower:*", "product:*"],
          read_claim_check_ref: "claim:context-read-phase6-m7",
          mutation_scan_ref: "scan:context-adapter-read-only-phase6-m7",
          mutation_permissions: []
        }),
      reply_publication: %{
        causal_unit_id: "causal-phase6-m7",
        phase: :final,
        dedupe_key: "causal-phase6-m7:final",
        body: "Done"
      },
      duplicate_suppression:
        Map.merge(scope, %{
          principal_ref: "principal:operator-phase6-m7",
          resource_ref: "semantic-publication:phase6-m7",
          idempotency_key: "semantic-dedupe:phase6-m7",
          trace_id: "trace-dedupe-phase6-m7",
          correlation_id: "correlation-dedupe-phase6-m7",
          semantic_idempotency_key: "semantic-gateway:phase6-m7",
          semantic_ref: "semantic:result-phase6-m7",
          suppression_ref: "suppression:phase6-m7",
          duplicate_of_ref: "semantic:result-phase6-m7",
          routing_fact_hash: "sha256:routing-facts-phase6-m7",
          publication_ref: "publication:causal-phase6-m7:final",
          operator_visibility: "visible",
          reason_code: "duplicate_semantic_publication"
        }),
      suppression_visibility:
        Map.merge(scope, %{
          principal_ref: "principal:operator-phase6-m7",
          resource_ref: "suppression:phase6-m7",
          idempotency_key: "suppression:phase6-m7",
          trace_id: "trace-suppression-phase6-m7",
          correlation_id: "correlation-suppression-phase6-m7",
          suppression_ref: "suppression:phase6-m7",
          suppression_kind: "duplicate_semantic_publication",
          reason_code: "duplicate_semantic_publication",
          target_ref: "publication:causal-phase6-m7:final",
          operator_visibility: "visible",
          recovery_action_refs: ["recovery:semantic-duplicate-phase6-m7"],
          diagnostics_ref: "diagnostics:suppression-phase6-m7"
        }),
      privacy_redaction_fixture:
        Map.merge(scope, %{
          system_actor_ref: "system:outer-brain",
          resource_ref: "dto:semantic-summary-phase6-m7",
          idempotency_key: "privacy-redaction:phase6-m7",
          trace_id: "trace-privacy-phase6-m7",
          correlation_id: "correlation-privacy-phase6-m7",
          redaction_policy_ref: "redaction:semantic-public-v1",
          raw_field_name: "raw_provider_body",
          public_field_name: "diagnostics_ref",
          redaction_class: "provider_payload",
          fixture_ref: "fixture:phase6-m7-privacy",
          scan_ref: "scan:phase6-m7-privacy",
          public_payload: %{
            semantic_ref: "semantic:result-phase6-m7",
            diagnostics_ref: "diagnostics:semantic-phase6-m7"
          },
          search_attributes: %{
            "SemanticRef" => "semantic:result-phase6-m7",
            "DiagnosticsRef" => "diagnostics:semantic-phase6-m7"
          }
        })
    }
  end

  @spec owner_evidence(map()) :: {:ok, map()} | {:error, term()}
  def owner_evidence(attrs) when is_map(attrs) do
    with :ok <- reject_forbidden_payload(attrs),
         :ok <- reject_shortcuts(attrs),
         :ok <- require_fields(attrs),
         {:ok, provenance} <-
           attrs
           |> fetch_required(:semantic_context_provenance)
           |> SemanticContextProvenance.new(),
         {:ok, failure} <- attrs |> fetch_required(:semantic_failure) |> SemanticFailure.new(),
         {:ok, adapter} <-
           attrs |> fetch_required(:context_adapter_read_only) |> ContextAdapterReadOnly.new(),
         {:ok, publication, replay_publication} <-
           attrs |> fetch_required(:reply_publication) |> reply_publication_pair(),
         {:ok, duplicate_suppression} <-
           attrs
           |> fetch_required(:duplicate_suppression)
           |> SemanticDuplicateSuppression.new(),
         {:ok, suppression_visibility} <-
           attrs |> fetch_required(:suppression_visibility) |> SuppressionVisibility.new(),
         {:ok, privacy_redaction} <-
           attrs |> fetch_required(:privacy_redaction_fixture) |> PrivacyRedactionFixture.new() do
      {:ok,
       evidence(%{
         attrs: attrs,
         provenance: provenance,
         failure: failure,
         adapter: adapter,
         publication: publication,
         replay_publication: replay_publication,
         duplicate_suppression: duplicate_suppression,
         suppression_visibility: suppression_visibility,
         privacy_redaction: privacy_redaction
       })}
    end
  end

  def owner_evidence(_attrs), do: {:error, :invalid_semantic_gateway_contract_evidence}

  defp require_fields(attrs) do
    missing = Enum.find(@required_fixture_fields, &(not present?(attrs, &1)))

    case missing do
      nil -> :ok
      field -> {:error, {:missing_required_semantic_gateway_evidence, field}}
    end
  end

  defp reject_forbidden_payload(attrs), do: Phase4SemanticContract.reject_forbidden_attrs(attrs)

  defp reject_shortcuts(attrs) do
    cond do
      fetch_value(attrs, :raw_payload_included?) == true ->
        {:error, :raw_payload_included}

      fetch_value(attrs, :provider_sdk_mock_proof?) == true ->
        {:error, :provider_sdk_local_mock_semantic_gateway_proof}

      fetch_value(attrs, :lower_runtime_only_proof?) == true or
          fetch_value(attrs, :real_outer_brain_surface?) == false ->
        {:error, :lower_runtime_only_semantic_gateway_proof}

      true ->
        :ok
    end
  end

  defp reply_publication_pair(attrs) when is_map(attrs) do
    with {:ok, first} <- build_reply_publication(attrs, "publication"),
         {:ok, replay} <- build_reply_publication(attrs, "publication-replay") do
      {:ok, first, replay}
    end
  end

  defp reply_publication_pair(_attrs), do: {:error, :invalid_reply_publication_evidence}

  defp build_reply_publication(attrs, prefix) do
    causal_unit_id = fetch_value(attrs, :causal_unit_id)
    phase = fetch_value(attrs, :phase)
    dedupe_key = fetch_value(attrs, :dedupe_key)
    body = fetch_value(attrs, :body)

    with {:ok, reply_body} <- ReplyBodyBoundary.build(causal_unit_id, phase, dedupe_key, body) do
      ReplyPublication.new(%{
        publication_id: "#{prefix}:#{causal_unit_id}:#{phase}",
        causal_unit_id: causal_unit_id,
        phase: phase,
        dedupe_key: dedupe_key,
        state: :published,
        body: reply_body.preview,
        body_ref: reply_body.ref
      })
    end
  end

  defp evidence(%{
         attrs: attrs,
         provenance: provenance,
         failure: failure,
         adapter: adapter,
         publication: publication,
         replay_publication: replay_publication,
         duplicate_suppression: duplicate_suppression,
         suppression_visibility: suppression_visibility,
         privacy_redaction: privacy_redaction
       }) do
    %{
      contract_id: @contract_id,
      owner_repo: "outer_brain",
      primary_repos: ["outer_brain", "stack_lab"],
      owner_surface_ref: fetch_value(attrs, :owner_surface_ref),
      real_outer_brain_surface?: fetch_value(attrs, :real_outer_brain_surface?),
      raw_payload_included?: fetch_value(attrs, :raw_payload_included?) == true,
      lower_runtime_only_proof?: fetch_value(attrs, :lower_runtime_only_proof?) == true,
      provider_sdk_mock_proof?: fetch_value(attrs, :provider_sdk_mock_proof?) == true,
      semantic_context_provenance_ref: provenance.semantic_ref,
      semantic_failure_ref: SemanticFailure.journal_entry_id(failure),
      read_only_context_adapter_boundary_ref: adapter.adapter_ref,
      reply_publication_refs: [publication.publication_id, replay_publication.publication_id],
      reply_publication_dedupe_ref: publication.dedupe_key,
      suppression_visibility_ref: suppression_visibility.suppression_ref,
      privacy_redaction_fixture_ref: privacy_redaction.fixture_ref,
      restart_replay_with_semantic_state_ref:
        fetch_value(attrs, :restart_replay_with_semantic_state_ref),
      raw_payload_scan_ref: fetch_value(attrs, :raw_payload_scan_ref),
      bounded_evidence_refs: bounded_evidence_refs(provenance, publication),
      semantic_failure_classification: %{
        kind: failure.kind,
        retry_class: failure.retry_class
      },
      reply_publication_dedupe: %{
        dedupe_key: publication.dedupe_key,
        same_body_ref?:
          ReplyBodyBoundary.equivalent_ref?(publication.body_ref, replay_publication.body_ref),
        user_visible_publication_count:
          user_visible_publication_count(publication, replay_publication)
      },
      duplicate_suppression: %{
        suppression_ref: duplicate_suppression.suppression_ref,
        duplicate_of_ref: duplicate_suppression.duplicate_of_ref,
        operator_visibility: duplicate_suppression.operator_visibility
      },
      suppression_visibility: %{
        operator_visibility: suppression_visibility.operator_visibility,
        recovery_action_refs: suppression_visibility.recovery_action_refs,
        diagnostics_ref: suppression_visibility.diagnostics_ref
      },
      privacy_redaction: %{
        raw_field_name: privacy_redaction.raw_field_name,
        public_field_name: privacy_redaction.public_field_name,
        public_payload_keys: privacy_redaction.public_payload |> Map.keys() |> Enum.sort()
      }
    }
  end

  defp bounded_evidence_refs(provenance, publication) do
    [
      provenance.input_claim_check_ref,
      provenance.output_claim_check_ref,
      publication.body_ref["artifact_id"]
    ]
  end

  defp user_visible_publication_count(%{dedupe_key: key} = first, %{dedupe_key: key} = replay) do
    if ReplyBodyBoundary.equivalent_ref?(first.body_ref, replay.body_ref), do: 1, else: 2
  end

  defp user_visible_publication_count(_first, _replay), do: 2

  defp present?(attrs, field), do: not is_nil(fetch_value(attrs, field))

  defp fetch_required(attrs, field), do: fetch_value(attrs, field)

  defp fetch_value(%{__struct__: _} = attrs, field) do
    attrs
    |> Map.from_struct()
    |> fetch_value(field)
  end

  defp fetch_value(attrs, field) when is_map(attrs) do
    cond do
      Map.has_key?(attrs, field) -> Map.fetch!(attrs, field)
      Map.has_key?(attrs, Atom.to_string(field)) -> Map.fetch!(attrs, Atom.to_string(field))
      true -> nil
    end
  end

  defp scope_attrs do
    %{
      tenant_ref: "tenant:phase6-m7",
      installation_ref: "installation:phase6-m7",
      workspace_ref: "workspace:phase6-m7",
      project_ref: "project:semantic-runtime",
      environment_ref: "environment:service-mode",
      authority_packet_ref: "authority:phase6-m7",
      permission_decision_ref: "permission:phase6-m7",
      release_manifest_ref: "phase6-m7-semantic-gateway-contract"
    }
  end
end
