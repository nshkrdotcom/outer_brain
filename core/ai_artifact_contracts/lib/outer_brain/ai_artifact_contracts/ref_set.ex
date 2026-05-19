defmodule OuterBrain.AIArtifactContracts.RefSet do
  @moduledoc "Composed adaptive artifact ref set for proof and reporting paths."

  alias OuterBrain.AIArtifactContracts.{
    EvaluationRefs,
    ModelRefs,
    OptimizationRefs,
    PromptRefs,
    RoutingRefs,
    Validator,
    Vocabulary
  }

  @enforce_keys [
    :tenant_ref,
    :artifact_graph_ref,
    :prompt_refs,
    :optimization_refs,
    :evaluation_refs,
    :routing_refs,
    :model_refs,
    :trace_ref,
    :redaction_policy_ref
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          tenant_ref: String.t(),
          artifact_graph_ref: String.t(),
          prompt_refs: PromptRefs.t(),
          optimization_refs: OptimizationRefs.t(),
          evaluation_refs: EvaluationRefs.t(),
          routing_refs: RoutingRefs.t(),
          model_refs: ModelRefs.t(),
          trace_ref: String.t(),
          redaction_policy_ref: String.t()
        }

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) when is_map(attrs) do
    with :ok <- Validator.reject_raw_payload(attrs),
         :ok <- Validator.reject_out_of_scope_owner(attrs),
         :ok <-
           Validator.required(
             attrs,
             Vocabulary.common_ref_fields() ++ Vocabulary.ref_set_fields()
           ),
         {:ok, prompt_refs} <- PromptRefs.new(attrs),
         {:ok, optimization_refs} <- OptimizationRefs.new(attrs),
         {:ok, evaluation_refs} <- EvaluationRefs.new(attrs),
         {:ok, routing_refs} <- RoutingRefs.new(attrs),
         {:ok, model_refs} <- ModelRefs.new(attrs) do
      {:ok,
       %__MODULE__{
         tenant_ref: Validator.value!(attrs, :tenant_ref),
         artifact_graph_ref: Validator.value!(attrs, :artifact_graph_ref),
         prompt_refs: prompt_refs,
         optimization_refs: optimization_refs,
         evaluation_refs: evaluation_refs,
         routing_refs: routing_refs,
         model_refs: model_refs,
         trace_ref: Validator.value!(attrs, :trace_ref),
         redaction_policy_ref: Validator.value!(attrs, :redaction_policy_ref)
       }}
    end
  end

  @spec to_projection(t()) :: map()
  def to_projection(%__MODULE__{} = ref_set) do
    prompt_refs = ref_set.prompt_refs
    optimization_refs = ref_set.optimization_refs
    evaluation_refs = ref_set.evaluation_refs
    routing_refs = ref_set.routing_refs
    model_refs = ref_set.model_refs

    %{
      redacted: true,
      tenant_ref: ref_set.tenant_ref,
      artifact_graph_ref: ref_set.artifact_graph_ref,
      prompt_artifact_ref: prompt_refs.prompt_artifact_ref.prompt_artifact_ref,
      role_pack_ref: prompt_refs.role_pack_ref.role_pack_ref,
      skill_ref: prompt_refs.skill_ref.skill_ref,
      gepa_component_ref: optimization_refs.gepa_component_ref.gepa_component_ref,
      candidate_ref: optimization_refs.candidate_ref.candidate_ref,
      candidate_delta_ref: optimization_refs.candidate_delta_ref.candidate_delta_ref,
      objective_ref: optimization_refs.objective_ref.objective_ref,
      optimization_run_ref: optimization_refs.optimization_run_ref.optimization_run_ref,
      eval_suite_ref: evaluation_refs.eval_suite_ref.eval_suite_ref,
      eval_run_ref: evaluation_refs.eval_run_ref.eval_run_ref,
      replay_bundle_ref: evaluation_refs.replay_bundle_ref.replay_bundle_ref,
      router_artifact_ref: routing_refs.router_artifact_ref.router_artifact_ref,
      router_decision_ref: routing_refs.router_decision_ref.router_decision_ref,
      verifier_artifact_ref: routing_refs.verifier_artifact_ref.verifier_artifact_ref,
      provider_pool_ref: model_refs.provider_pool_ref.provider_pool_ref,
      model_profile_ref: model_refs.model_profile_ref.model_profile_ref,
      endpoint_profile_ref: model_refs.endpoint_profile_ref.endpoint_profile_ref,
      promotion_ref: optimization_refs.promotion_ref.promotion_ref,
      rollback_ref: optimization_refs.rollback_ref.rollback_ref,
      trace_ref: ref_set.trace_ref,
      redaction_policy_ref: ref_set.redaction_policy_ref
    }
  end
end
