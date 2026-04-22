defmodule OuterBrain.Bridges.ProjectionPublicationTest do
  use ExUnit.Case, async: true

  alias OuterBrain.Bridges.ProjectionPublication
  alias OuterBrain.Contracts.ReplyBodyBoundary
  alias OuterBrain.Contracts.ReplyPublication

  test "reply publications can be projected into a ground-plane-style shape" do
    assert {:ok, reply_body} =
             ReplyBodyBoundary.build("causal_1", :final, "causal_1:final", "Done")

    assert {:ok, publication} =
             ReplyPublication.new(%{
               publication_id: "publication_1",
               causal_unit_id: "causal_1",
               phase: :final,
               dedupe_key: "causal_1:final",
               state: :published,
               body: reply_body.preview,
               body_ref: reply_body.ref
             })

    assert %{
             stream: "semantic_publications",
             rows: [%{phase: :final, body_ref: body_ref}]
           } =
             ProjectionPublication.build(publication)

    assert body_ref["body_hash"] == reply_body.ref["body_hash"]
  end
end
