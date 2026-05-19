defmodule OuterBrain.AIArtifactContracts.ProviderPoolRef do
  @moduledoc "Governed provider pool ref."
  @enforce_keys [:provider_pool_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.ModelProfileRef do
  @moduledoc "Model profile ref."
  @enforce_keys [:model_profile_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.EndpointProfileRef do
  @moduledoc "Endpoint profile ref."
  @enforce_keys [:endpoint_profile_ref, :tenant_ref, :trace_ref, :redaction_policy_ref]
  defstruct @enforce_keys
  @type t :: %__MODULE__{}
end

defmodule OuterBrain.AIArtifactContracts.ModelRefs do
  @moduledoc "Provider pool, model profile, and endpoint profile refs."

  alias OuterBrain.AIArtifactContracts.{
    EndpointProfileRef,
    ModelProfileRef,
    ProviderPoolRef,
    Validator
  }

  @enforce_keys [:provider_pool_ref, :model_profile_ref, :endpoint_profile_ref]
  defstruct @enforce_keys

  @type t :: %__MODULE__{
          provider_pool_ref: ProviderPoolRef.t(),
          model_profile_ref: ModelProfileRef.t(),
          endpoint_profile_ref: EndpointProfileRef.t()
        }

  @spec new(map()) :: {:ok, t()}
  def new(attrs) do
    {:ok,
     %__MODULE__{
       provider_pool_ref: Validator.simple_ref(ProviderPoolRef, attrs, :provider_pool_ref),
       model_profile_ref: Validator.simple_ref(ModelProfileRef, attrs, :model_profile_ref),
       endpoint_profile_ref:
         Validator.simple_ref(EndpointProfileRef, attrs, :endpoint_profile_ref)
     }}
  end
end
