defmodule OuterBrain.AIArtifactContracts.PromptArtifactRef do
  @moduledoc "Prompt artifact identity without prompt body."
  @enforce_keys [:prompt_artifact_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.RolePackRef do
  @moduledoc "Role pack identity without role prompt body."
  @enforce_keys [:role_pack_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.SkillRef do
  @moduledoc "Inherited skill capability ref owned by OuterBrain in this layer."
  @enforce_keys [:skill_ref, :owner_scope, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}

  alias OuterBrain.AIArtifactContracts.Validator

  @spec from_ref_set(map()) :: {:ok, t()} | {:error, term()}
  def from_ref_set(attrs) do
    attrs
    |> Validator.value!(:skill_ref)
    |> case do
      skill_attrs when is_map(skill_attrs) ->
        with :ok <- Validator.required(skill_attrs, [:skill_ref, :owner_scope]),
             {:ok, owner_scope} <- Validator.outer_brain_owner(skill_attrs) do
          {:ok,
           %__MODULE__{
             skill_ref: Validator.value!(skill_attrs, :skill_ref),
             owner_scope: owner_scope,
             tenant_ref: Validator.value!(attrs, :tenant_ref),
             trace_ref: Validator.value!(attrs, :trace_ref),
             redaction_policy_ref: Validator.value!(attrs, :redaction_policy_ref)
           }}
        end

      skill_ref when is_binary(skill_ref) ->
        {:ok,
         %__MODULE__{
           skill_ref: skill_ref,
           owner_scope: :outer_brain,
           tenant_ref: Validator.value!(attrs, :tenant_ref),
           trace_ref: Validator.value!(attrs, :trace_ref),
           redaction_policy_ref: Validator.value!(attrs, :redaction_policy_ref)
         }}

      _other ->
        {:error, {:invalid_ai_artifact_ref, :skill_ref}}
    end
  end
end

defmodule OuterBrain.AIArtifactContracts.PromptRefs do
  @moduledoc "Prompt, role, and skill identity refs for an adaptive artifact graph."

  alias OuterBrain.AIArtifactContracts.{
    PromptArtifactRef,
    RolePackRef,
    SkillRef,
    Validator
  }

  @enforce_keys [:prompt_artifact_ref, :role_pack_ref, :skill_ref]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          prompt_artifact_ref: PromptArtifactRef.t(),
          role_pack_ref: RolePackRef.t(),
          skill_ref: SkillRef.t()
        }

  @spec new(map()) :: {:ok, t()} | {:error, term()}
  def new(attrs) do
    with {:ok, skill_ref} <- SkillRef.from_ref_set(attrs) do
      {:ok,
       %__MODULE__{
         prompt_artifact_ref:
           Validator.simple_ref(PromptArtifactRef, attrs, :prompt_artifact_ref),
         role_pack_ref: Validator.simple_ref(RolePackRef, attrs, :role_pack_ref),
         skill_ref: skill_ref
       }}
    end
  end
end
