defmodule OuterBrain.AIArtifactContracts.EvalSuiteRef do
  @moduledoc "Eval suite ref."
  @enforce_keys [:eval_suite_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.EvalRunRef do
  @moduledoc "Eval run ref."
  @enforce_keys [:eval_run_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.ReplayBundleRef do
  @moduledoc "AITrace replay bundle ref."
  @enforce_keys [:replay_bundle_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.EvaluationRefs do
  @moduledoc "Evaluation and replay refs."

  alias OuterBrain.AIArtifactContracts.{EvalRunRef, EvalSuiteRef, ReplayBundleRef, Validator}

  @enforce_keys [:eval_suite_ref, :eval_run_ref, :replay_bundle_ref]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          eval_suite_ref: EvalSuiteRef.t(),
          eval_run_ref: EvalRunRef.t(),
          replay_bundle_ref: ReplayBundleRef.t()
        }

  @spec new(map()) :: {:ok, t()}
  def new(attrs) do
    {:ok,
     %__MODULE__{
       eval_suite_ref: Validator.simple_ref(EvalSuiteRef, attrs, :eval_suite_ref),
       eval_run_ref: Validator.simple_ref(EvalRunRef, attrs, :eval_run_ref),
       replay_bundle_ref: Validator.simple_ref(ReplayBundleRef, attrs, :replay_bundle_ref)
     }}
  end
end
