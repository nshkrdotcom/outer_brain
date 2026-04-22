defmodule OuterBrain.Bridges.ProjectionPublication do
  @moduledoc """
  Produces a projection-friendly publication shape from a semantic reply.
  """

  alias OuterBrain.Contracts.ReplyPublication

  @spec build(ReplyPublication.t()) :: map()
  def build(%ReplyPublication{} = publication) do
    %{
      stream: "semantic_publications",
      op: "upsert",
      rows: [
        %{
          id: publication.publication_id,
          causal_unit_id: publication.causal_unit_id,
          phase: publication.phase,
          state: publication.state,
          body_ref: publication.body_ref
        }
      ]
    }
  end
end
