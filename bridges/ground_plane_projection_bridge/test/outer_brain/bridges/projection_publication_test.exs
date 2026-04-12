defmodule OuterBrain.Bridges.ProjectionPublicationTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Bridges.ProjectionPublication
  alias OuterBrain.Contracts.ReplyPublication

  test "reply publications can be projected into a ground-plane-style shape" do
    assert {:ok, publication} =
             ReplyPublication.new(%{
               publication_id: "publication_1",
               causal_unit_id: "causal_1",
               phase: :final,
               dedupe_key: "causal_1:final",
               state: :published,
               body: "Done"
             })

    assert %{stream: "semantic_publications", rows: [%{phase: :final}]} =
             ProjectionPublication.build(publication)
  end
end
