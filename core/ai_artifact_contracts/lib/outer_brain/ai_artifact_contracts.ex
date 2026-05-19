defmodule OuterBrain.AIArtifactContracts do
  @moduledoc """
  Ref-only adaptive artifact identity contracts.

  The public facade preserves the package API while artifact identity,
  optimization, evaluation, routing, model, lineage, and policy facts live in
  composed structs under `OuterBrain.AIArtifactContracts`.
  """

  alias OuterBrain.AIArtifactContracts.{PolicyArtifactRef, RefSet}

  @spec build_ref_set(map()) :: {:ok, RefSet.t()} | {:error, term()}
  def build_ref_set(attrs), do: RefSet.new(attrs)

  @spec policy_artifact_ref(map()) :: {:ok, PolicyArtifactRef.t()} | {:error, term()}
  def policy_artifact_ref(attrs), do: PolicyArtifactRef.new(attrs)

  @spec to_projection(RefSet.t()) :: map()
  def to_projection(%RefSet{} = ref_set), do: RefSet.to_projection(ref_set)
end
