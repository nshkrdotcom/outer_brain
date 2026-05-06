defmodule OuterBrain.AIArtifactContracts do
  @moduledoc """
  Ref-only adaptive artifact identity contracts.
  """

  @common_ref_fields [
    :tenant_ref,
    :artifact_graph_ref,
    :trace_ref,
    :redaction_policy_ref
  ]
  @ref_set_fields [
    :prompt_artifact_ref,
    :role_pack_ref,
    :skill_ref,
    :gepa_component_ref,
    :candidate_ref,
    :candidate_delta_ref,
    :objective_ref,
    :optimization_run_ref,
    :eval_suite_ref,
    :eval_run_ref,
    :replay_bundle_ref,
    :router_artifact_ref,
    :router_decision_ref,
    :verifier_artifact_ref,
    :provider_pool_ref,
    :model_profile_ref,
    :endpoint_profile_ref,
    :promotion_ref,
    :rollback_ref
  ]
  @policy_artifact_fields [
    :artifact_ref,
    :artifact_kind,
    :tenant_ref,
    :source_ref,
    :lineage_ref,
    :rollback_ref,
    :trace_ref,
    :redaction_policy_ref
  ]
  @raw_keys [
    :body,
    :raw_body,
    :prompt_body,
    :raw_prompt,
    :provider_payload,
    :raw_provider_payload,
    :payload,
    :raw_payload,
    :memory_body,
    :model_output,
    :tool_input,
    :tool_output,
    :credential_body,
    :api_key,
    :authorization_header,
    "body",
    "raw_body",
    "prompt_body",
    "raw_prompt",
    "provider_payload",
    "raw_provider_payload",
    "payload",
    "raw_payload",
    "memory_body",
    "model_output",
    "tool_input",
    "tool_output",
    "credential_body",
    "api_key",
    "authorization_header"
  ]
  @policy_artifact_kinds [
    :prompt_policy,
    :role_pack,
    :tool_policy,
    :retrieval_policy,
    :router_policy,
    :verifier_artifact
  ]

  defmodule RefSet do
    @moduledoc "Complete adaptive artifact ref set."
    @enforce_keys [
      :tenant_ref,
      :artifact_graph_ref,
      :prompt_artifact_ref,
      :role_pack_ref,
      :skill_ref,
      :gepa_component_ref,
      :candidate_ref,
      :candidate_delta_ref,
      :objective_ref,
      :optimization_run_ref,
      :eval_suite_ref,
      :eval_run_ref,
      :replay_bundle_ref,
      :router_artifact_ref,
      :router_decision_ref,
      :verifier_artifact_ref,
      :provider_pool_ref,
      :model_profile_ref,
      :endpoint_profile_ref,
      :promotion_ref,
      :rollback_ref,
      :trace_ref,
      :redaction_policy_ref
    ]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule PromptArtifactRef do
    @moduledoc "Prompt artifact identity without prompt body."
    @enforce_keys [:prompt_artifact_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule RolePackRef do
    @moduledoc "Role pack identity without role prompt body."
    @enforce_keys [:role_pack_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule SkillRef do
    @moduledoc "Inherited skill capability ref owned by OuterBrain in this layer."
    @enforce_keys [:skill_ref, :owner_scope, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule GEPAComponentRef do
    @moduledoc "GEPA component ref at an adaptive boundary."
    @enforce_keys [:gepa_component_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule CandidateRef do
    @moduledoc "GEPA candidate ref with lineage refs only."
    @enforce_keys [
      :candidate_ref,
      :parent_candidate_refs,
      :objective_ref,
      :checkpoint_ref,
      :tenant_ref,
      :trace_ref,
      :redaction_policy_ref
    ]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule CandidateDeltaRef do
    @moduledoc "GEPA candidate delta ref."
    @enforce_keys [:candidate_delta_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule ObjectiveRef do
    @moduledoc "Optimization objective ref."
    @enforce_keys [:objective_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule OptimizationRunRef do
    @moduledoc "Optimization run envelope ref."
    @enforce_keys [:optimization_run_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule EvalSuiteRef do
    @moduledoc "Eval suite ref."
    @enforce_keys [:eval_suite_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule EvalRunRef do
    @moduledoc "Eval run ref."
    @enforce_keys [:eval_run_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule ReplayBundleRef do
    @moduledoc "AITrace replay bundle ref."
    @enforce_keys [:replay_bundle_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule RouterArtifactRef do
    @moduledoc "TRINITY router artifact ref."
    @enforce_keys [:router_artifact_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule RouterDecisionRef do
    @moduledoc "Router decision ref."
    @enforce_keys [:router_decision_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule VerifierArtifactRef do
    @moduledoc "Verifier artifact ref."
    @enforce_keys [:verifier_artifact_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule ProviderPoolRef do
    @moduledoc "Governed provider pool ref."
    @enforce_keys [:provider_pool_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule ModelProfileRef do
    @moduledoc "Model profile ref."
    @enforce_keys [:model_profile_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule EndpointProfileRef do
    @moduledoc "Endpoint profile ref."
    @enforce_keys [:endpoint_profile_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule PromotionRef do
    @moduledoc "Promotion decision ref."
    @enforce_keys [:promotion_ref, :rollback_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule RollbackRef do
    @moduledoc "Rollback decision ref."
    @enforce_keys [:rollback_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  defmodule PolicyArtifactRef do
    @moduledoc "Lineage and rollback-bearing policy artifact ref."
    @enforce_keys [
      :artifact_ref,
      :artifact_kind,
      :tenant_ref,
      :source_ref,
      :lineage_ref,
      :rollback_ref,
      :trace_ref,
      :redaction_policy_ref
    ]
    defstruct @enforce_keys
    @type t :: %__MODULE__{}
  end

  @spec build_ref_set(map()) :: {:ok, RefSet.t()} | {:error, term()}
  def build_ref_set(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         :ok <- reject_out_of_scope_owner(attrs),
         :ok <- required(attrs, @common_ref_fields ++ @ref_set_fields),
         {:ok, skill_ref} <- skill_ref(attrs),
         {:ok, candidate_ref} <- candidate_ref(attrs),
         {:ok, promotion_ref} <- promotion_ref(attrs) do
      {:ok,
       %RefSet{
         tenant_ref: value!(attrs, :tenant_ref),
         artifact_graph_ref: value!(attrs, :artifact_graph_ref),
         prompt_artifact_ref: simple_ref(PromptArtifactRef, attrs, :prompt_artifact_ref),
         role_pack_ref: simple_ref(RolePackRef, attrs, :role_pack_ref),
         skill_ref: skill_ref,
         gepa_component_ref: simple_ref(GEPAComponentRef, attrs, :gepa_component_ref),
         candidate_ref: candidate_ref,
         candidate_delta_ref: simple_ref(CandidateDeltaRef, attrs, :candidate_delta_ref),
         objective_ref: simple_ref(ObjectiveRef, attrs, :objective_ref),
         optimization_run_ref: simple_ref(OptimizationRunRef, attrs, :optimization_run_ref),
         eval_suite_ref: simple_ref(EvalSuiteRef, attrs, :eval_suite_ref),
         eval_run_ref: simple_ref(EvalRunRef, attrs, :eval_run_ref),
         replay_bundle_ref: simple_ref(ReplayBundleRef, attrs, :replay_bundle_ref),
         router_artifact_ref: simple_ref(RouterArtifactRef, attrs, :router_artifact_ref),
         router_decision_ref: simple_ref(RouterDecisionRef, attrs, :router_decision_ref),
         verifier_artifact_ref: simple_ref(VerifierArtifactRef, attrs, :verifier_artifact_ref),
         provider_pool_ref: simple_ref(ProviderPoolRef, attrs, :provider_pool_ref),
         model_profile_ref: simple_ref(ModelProfileRef, attrs, :model_profile_ref),
         endpoint_profile_ref: simple_ref(EndpointProfileRef, attrs, :endpoint_profile_ref),
         promotion_ref: promotion_ref,
         rollback_ref: simple_ref(RollbackRef, attrs, :rollback_ref),
         trace_ref: value!(attrs, :trace_ref),
         redaction_policy_ref: value!(attrs, :redaction_policy_ref)
       }}
    end
  end

  @spec policy_artifact_ref(map()) :: {:ok, PolicyArtifactRef.t()} | {:error, term()}
  def policy_artifact_ref(attrs) when is_map(attrs) do
    with :ok <- reject_raw_payload(attrs),
         :ok <- reject_out_of_scope_owner(attrs),
         :ok <- required(attrs, @policy_artifact_fields),
         {:ok, artifact_kind} <- member(attrs, :artifact_kind, @policy_artifact_kinds) do
      {:ok,
       %PolicyArtifactRef{
         artifact_ref: value!(attrs, :artifact_ref),
         artifact_kind: artifact_kind,
         tenant_ref: value!(attrs, :tenant_ref),
         source_ref: value!(attrs, :source_ref),
         lineage_ref: value!(attrs, :lineage_ref),
         rollback_ref: value!(attrs, :rollback_ref),
         trace_ref: value!(attrs, :trace_ref),
         redaction_policy_ref: value!(attrs, :redaction_policy_ref)
       }}
    end
  end

  @spec to_projection(RefSet.t()) :: map()
  def to_projection(%RefSet{} = ref_set) do
    %{
      redacted: true,
      tenant_ref: ref_set.tenant_ref,
      artifact_graph_ref: ref_set.artifact_graph_ref,
      prompt_artifact_ref: ref_set.prompt_artifact_ref.prompt_artifact_ref,
      role_pack_ref: ref_set.role_pack_ref.role_pack_ref,
      skill_ref: ref_set.skill_ref.skill_ref,
      gepa_component_ref: ref_set.gepa_component_ref.gepa_component_ref,
      candidate_ref: ref_set.candidate_ref.candidate_ref,
      candidate_delta_ref: ref_set.candidate_delta_ref.candidate_delta_ref,
      objective_ref: ref_set.objective_ref.objective_ref,
      optimization_run_ref: ref_set.optimization_run_ref.optimization_run_ref,
      eval_suite_ref: ref_set.eval_suite_ref.eval_suite_ref,
      eval_run_ref: ref_set.eval_run_ref.eval_run_ref,
      replay_bundle_ref: ref_set.replay_bundle_ref.replay_bundle_ref,
      router_artifact_ref: ref_set.router_artifact_ref.router_artifact_ref,
      router_decision_ref: ref_set.router_decision_ref.router_decision_ref,
      verifier_artifact_ref: ref_set.verifier_artifact_ref.verifier_artifact_ref,
      provider_pool_ref: ref_set.provider_pool_ref.provider_pool_ref,
      model_profile_ref: ref_set.model_profile_ref.model_profile_ref,
      endpoint_profile_ref: ref_set.endpoint_profile_ref.endpoint_profile_ref,
      promotion_ref: ref_set.promotion_ref.promotion_ref,
      rollback_ref: ref_set.rollback_ref.rollback_ref,
      trace_ref: ref_set.trace_ref,
      redaction_policy_ref: ref_set.redaction_policy_ref
    }
  end

  defp simple_ref(module, attrs, field) do
    struct(module, [
      {field, value!(attrs, field)},
      {:tenant_ref, value!(attrs, :tenant_ref)},
      {:trace_ref, value!(attrs, :trace_ref)},
      {:redaction_policy_ref, value!(attrs, :redaction_policy_ref)}
    ])
  end

  defp skill_ref(attrs) do
    attrs
    |> value!(:skill_ref)
    |> case do
      skill_attrs when is_map(skill_attrs) ->
        with :ok <- required(skill_attrs, [:skill_ref, :owner_scope]),
             {:ok, owner_scope} <- outer_brain_owner(skill_attrs) do
          {:ok,
           %SkillRef{
             skill_ref: value!(skill_attrs, :skill_ref),
             owner_scope: owner_scope,
             tenant_ref: value!(attrs, :tenant_ref),
             trace_ref: value!(attrs, :trace_ref),
             redaction_policy_ref: value!(attrs, :redaction_policy_ref)
           }}
        end

      skill_ref when is_binary(skill_ref) ->
        {:ok,
         %SkillRef{
           skill_ref: skill_ref,
           owner_scope: :outer_brain,
           tenant_ref: value!(attrs, :tenant_ref),
           trace_ref: value!(attrs, :trace_ref),
           redaction_policy_ref: value!(attrs, :redaction_policy_ref)
         }}

      _other ->
        {:error, {:invalid_ai_artifact_ref, :skill_ref}}
    end
  end

  defp candidate_ref(attrs) do
    attrs
    |> value!(:candidate_ref)
    |> case do
      candidate_attrs when is_map(candidate_attrs) ->
        with :ok <-
               required(candidate_attrs, [
                 :candidate_ref,
                 :parent_candidate_refs,
                 :objective_ref,
                 :checkpoint_ref
               ]),
             parents when is_list(parents) <- value(candidate_attrs, :parent_candidate_refs) do
          {:ok,
           %CandidateRef{
             candidate_ref: value!(candidate_attrs, :candidate_ref),
             parent_candidate_refs: parents,
             objective_ref: value!(candidate_attrs, :objective_ref),
             checkpoint_ref: value!(candidate_attrs, :checkpoint_ref),
             tenant_ref: value!(attrs, :tenant_ref),
             trace_ref: value!(attrs, :trace_ref),
             redaction_policy_ref: value!(attrs, :redaction_policy_ref)
           }}
        else
          _other -> {:error, {:invalid_ai_artifact_ref, :candidate_ref}}
        end

      candidate_ref when is_binary(candidate_ref) ->
        {:ok,
         %CandidateRef{
           candidate_ref: candidate_ref,
           parent_candidate_refs: [],
           objective_ref: value!(attrs, :objective_ref),
           checkpoint_ref: value(attrs, :checkpoint_ref),
           tenant_ref: value!(attrs, :tenant_ref),
           trace_ref: value!(attrs, :trace_ref),
           redaction_policy_ref: value!(attrs, :redaction_policy_ref)
         }}

      _other ->
        {:error, {:invalid_ai_artifact_ref, :candidate_ref}}
    end
  end

  defp promotion_ref(attrs) do
    attrs
    |> value!(:promotion_ref)
    |> case do
      promotion_attrs when is_map(promotion_attrs) ->
        with :ok <- required(promotion_attrs, [:promotion_ref, :rollback_ref]) do
          {:ok,
           %PromotionRef{
             promotion_ref: value!(promotion_attrs, :promotion_ref),
             rollback_ref: value!(promotion_attrs, :rollback_ref),
             tenant_ref: value!(attrs, :tenant_ref),
             trace_ref: value!(attrs, :trace_ref),
             redaction_policy_ref: value!(attrs, :redaction_policy_ref)
           }}
        end

      promotion_ref when is_binary(promotion_ref) ->
        {:ok,
         %PromotionRef{
           promotion_ref: promotion_ref,
           rollback_ref: value!(attrs, :rollback_ref),
           tenant_ref: value!(attrs, :tenant_ref),
           trace_ref: value!(attrs, :trace_ref),
           redaction_policy_ref: value!(attrs, :redaction_policy_ref)
         }}

      _other ->
        {:error, {:invalid_ai_artifact_ref, :promotion_ref}}
    end
  end

  defp reject_raw_payload(attrs) do
    case Enum.find(@raw_keys, &has_key_deep?(attrs, &1)) do
      nil -> :ok
      key -> {:error, {:raw_ai_artifact_payload_forbidden, key}}
    end
  end

  defp reject_out_of_scope_owner(attrs) do
    cond do
      jido_skill_owner?(value(attrs, :owner_scope)) ->
        {:error, {:out_of_scope_owner, :jido_skill}}

      attrs |> value(:skill_ref) |> skill_owner_scope() |> jido_skill_owner?() ->
        {:error, {:out_of_scope_owner, :jido_skill}}

      true ->
        :ok
    end
  end

  defp skill_owner_scope(%{} = skill_attrs), do: value(skill_attrs, :owner_scope)
  defp skill_owner_scope(_other), do: nil

  defp outer_brain_owner(attrs) do
    case value(attrs, :owner_scope) do
      :outer_brain ->
        {:ok, :outer_brain}

      "outer_brain" ->
        {:ok, :outer_brain}

      other when other in [:jido_skill, "jido_skill"] ->
        {:error, {:out_of_scope_owner, :jido_skill}}

      _other ->
        {:error, {:invalid_ai_artifact_ref, :owner_scope}}
    end
  end

  defp jido_skill_owner?(owner), do: owner in [:jido_skill, "jido_skill"]

  defp required(attrs, fields) do
    case Enum.find(fields, &(not present?(value(attrs, &1)))) do
      nil -> :ok
      field -> {:error, {:missing_ai_artifact_ref, field}}
    end
  end

  defp member(attrs, field, allowed) do
    candidate = value(attrs, field)

    if candidate in allowed do
      {:ok, candidate}
    else
      {:error, {:invalid_ai_artifact_ref, field}}
    end
  end

  defp has_key_deep?(attrs, key) when is_map(attrs) do
    Map.has_key?(attrs, key) or Enum.any?(Map.values(attrs), &has_key_deep?(&1, key))
  end

  defp has_key_deep?(items, key) when is_list(items),
    do: Enum.any?(items, &has_key_deep?(&1, key))

  defp has_key_deep?(_value, _key), do: false

  defp present?(value) when is_binary(value), do: String.trim(value) != ""
  defp present?(value) when is_list(value), do: value != []
  defp present?(value) when is_map(value), do: map_size(value) > 0
  defp present?(value), do: not is_nil(value)

  defp value!(attrs, field), do: value(attrs, field)
  defp value(attrs, field), do: Map.get(attrs, field) || Map.get(attrs, Atom.to_string(field))
end
