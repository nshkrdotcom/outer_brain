defmodule OuterBrain.Bridges.IntentEnvelope do
  @moduledoc """
  Projects an action request into a Citadel-facing structured envelope.
  """

  alias OuterBrain.Contracts.ActionRequest

  @spec build(ActionRequest.t()) :: map()
  def build(%ActionRequest{} = request) do
    %{
      intent_id: request.request_id,
      manifest_id: request.manifest_id,
      route: request.route,
      args: request.args,
      provenance: request.provenance
    }
  end
end
