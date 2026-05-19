defmodule OuterBrain.AIArtifactContracts.RouterArtifactRef do
  @moduledoc "TRINITY router artifact ref."
  @enforce_keys [:router_artifact_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.RouterDecisionRef do
  @moduledoc "Router decision ref."
  @enforce_keys [:router_decision_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.VerifierArtifactRef do
  @moduledoc "Verifier artifact ref."
  @enforce_keys [:verifier_artifact_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.RoutingRefs do
  @moduledoc "Router decision and verifier refs."

  alias OuterBrain.AIArtifactContracts.{
    RouterArtifactRef,
    RouterDecisionRef,
    Validator,
    VerifierArtifactRef
  }

  @enforce_keys [:router_artifact_ref, :router_decision_ref, :verifier_artifact_ref]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          router_artifact_ref: RouterArtifactRef.t(),
          router_decision_ref: RouterDecisionRef.t(),
          verifier_artifact_ref: VerifierArtifactRef.t()
        }

  @spec new(map()) :: {:ok, t()}
  def new(attrs) do
    {:ok,
     %__MODULE__{
       router_artifact_ref: Validator.simple_ref(RouterArtifactRef, attrs, :router_artifact_ref),
       router_decision_ref: Validator.simple_ref(RouterDecisionRef, attrs, :router_decision_ref),
       verifier_artifact_ref:
         Validator.simple_ref(VerifierArtifactRef, attrs, :verifier_artifact_ref)
     }}
  end
end
