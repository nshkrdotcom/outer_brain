defmodule OuterBrain.AIArtifactContracts.GEPAComponentRef do
  @moduledoc "GEPA component ref at an adaptive boundary."
  @enforce_keys [:gepa_component_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.CandidateRef do
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

  alias OuterBrain.AIArtifactContracts.Validator

  @spec from_ref_set(map()) :: {:ok, t()} | {:error, term()}
  def from_ref_set(attrs) do
    attrs
    |> Validator.value!(:candidate_ref)
    |> case do
      candidate_attrs when is_map(candidate_attrs) ->
        with :ok <-
               Validator.required(candidate_attrs, [
                 :candidate_ref,
                 :parent_candidate_refs,
                 :objective_ref,
                 :checkpoint_ref
               ]),
             parents when is_list(parents) <-
               Validator.value(candidate_attrs, :parent_candidate_refs) do
          {:ok,
           %__MODULE__{
             candidate_ref: Validator.value!(candidate_attrs, :candidate_ref),
             parent_candidate_refs: parents,
             objective_ref: Validator.value!(candidate_attrs, :objective_ref),
             checkpoint_ref: Validator.value!(candidate_attrs, :checkpoint_ref),
             tenant_ref: Validator.value!(attrs, :tenant_ref),
             trace_ref: Validator.value!(attrs, :trace_ref),
             redaction_policy_ref: Validator.value!(attrs, :redaction_policy_ref)
           }}
        else
          _other -> {:error, {:invalid_ai_artifact_ref, :candidate_ref}}
        end

      candidate_ref when is_binary(candidate_ref) ->
        {:ok,
         %__MODULE__{
           candidate_ref: candidate_ref,
           parent_candidate_refs: [],
           objective_ref: Validator.value!(attrs, :objective_ref),
           checkpoint_ref: Validator.value(attrs, :checkpoint_ref),
           tenant_ref: Validator.value!(attrs, :tenant_ref),
           trace_ref: Validator.value!(attrs, :trace_ref),
           redaction_policy_ref: Validator.value!(attrs, :redaction_policy_ref)
         }}

      _other ->
        {:error, {:invalid_ai_artifact_ref, :candidate_ref}}
    end
  end
end

defmodule OuterBrain.AIArtifactContracts.CandidateDeltaRef do
  @moduledoc "GEPA candidate delta ref."
  @enforce_keys [:candidate_delta_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.ObjectiveRef do
  @moduledoc "Optimization objective ref."
  @enforce_keys [:objective_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.OptimizationRunRef do
  @moduledoc "Optimization run envelope ref."
  @enforce_keys [:optimization_run_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.PromotionRef do
  @moduledoc "Promotion decision ref."
  @enforce_keys [:promotion_ref, :rollback_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}

  alias OuterBrain.AIArtifactContracts.Validator

  @spec from_ref_set(map()) :: {:ok, t()} | {:error, term()}
  def from_ref_set(attrs) do
    attrs
    |> Validator.value!(:promotion_ref)
    |> case do
      promotion_attrs when is_map(promotion_attrs) ->
        with :ok <- Validator.required(promotion_attrs, [:promotion_ref, :rollback_ref]) do
          {:ok,
           %__MODULE__{
             promotion_ref: Validator.value!(promotion_attrs, :promotion_ref),
             rollback_ref: Validator.value!(promotion_attrs, :rollback_ref),
             tenant_ref: Validator.value!(attrs, :tenant_ref),
             trace_ref: Validator.value!(attrs, :trace_ref),
             redaction_policy_ref: Validator.value!(attrs, :redaction_policy_ref)
           }}
        end

      promotion_ref when is_binary(promotion_ref) ->
        {:ok,
         %__MODULE__{
           promotion_ref: promotion_ref,
           rollback_ref: Validator.value!(attrs, :rollback_ref),
           tenant_ref: Validator.value!(attrs, :tenant_ref),
           trace_ref: Validator.value!(attrs, :trace_ref),
           redaction_policy_ref: Validator.value!(attrs, :redaction_policy_ref)
         }}

      _other ->
        {:error, {:invalid_ai_artifact_ref, :promotion_ref}}
    end
  end
end

defmodule OuterBrain.AIArtifactContracts.RollbackRef do
  @moduledoc "Rollback decision ref."
  @enforce_keys [:rollback_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.OptimizationRefs do
  @moduledoc "Optimization, candidate, promotion, and rollback refs."

  alias OuterBrain.AIArtifactContracts.{
    CandidateDeltaRef,
    CandidateRef,
    GEPAComponentRef,
    ObjectiveRef,
    OptimizationRunRef,
    PromotionRef,
    RollbackRef,
    Validator
  }

  @enforce_keys [
    :gepa_component_ref,
    :candidate_ref,
    :candidate_delta_ref,
    :objective_ref,
    :optimization_run_ref,
    :promotion_ref,
    :rollback_ref
  ]
  defstruct @enforce_keys

  @type t :: %__MODULE__{}

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) do
    with {:ok, candidate_ref} <- CandidateRef.from_ref_set(attrs),
         {:ok, promotion_ref} <- PromotionRef.from_ref_set(attrs) do
      {:ok,
       %__MODULE__{
         gepa_component_ref: Validator.simple_ref(GEPAComponentRef, attrs, :gepa_component_ref),
         candidate_ref: candidate_ref,
         candidate_delta_ref:
           Validator.simple_ref(CandidateDeltaRef, attrs, :candidate_delta_ref),
         objective_ref: Validator.simple_ref(ObjectiveRef, attrs, :objective_ref),
         optimization_run_ref:
           Validator.simple_ref(OptimizationRunRef, attrs, :optimization_run_ref),
         promotion_ref: promotion_ref,
         rollback_ref: Validator.simple_ref(RollbackRef, attrs, :rollback_ref)
       }}
    end
  end
end
