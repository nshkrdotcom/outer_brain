defmodule OuterBrain.Persistence.ReplyPublicationMapper do
  @moduledoc false

  alias OuterBrain.Journal.Tables.ReplyPublicationRecord

  @spec to_schema_attrs(String.t(), ReplyPublicationRecord.t(), map()) :: map()
  def to_schema_attrs(tenant_id, %ReplyPublicationRecord{} = publication, lineage) do
    %{
      publication_id: publication.publication_id,
      tenant_id: tenant_id,
      causal_unit_id: publication.causal_unit_id,
      phase: publication.phase,
      state: publication.state,
      dedupe_key: publication.dedupe_key,
      body: publication.body,
      body_ref: publication.body_ref,
      run_ref: lineage.run_ref,
      turn_ref: lineage.turn_ref,
      attempt_ref: lineage.attempt_ref,
      reply_artifact_ref: lineage.reply_artifact_ref,
      next_semantic_ref: lineage.next_semantic_ref
    }
  end

  @spec from_schema(struct()) :: ReplyPublicationRecord.t()
  def from_schema(schema) do
    {:ok, publication} =
      ReplyPublicationRecord.new(%{
        publication_id: schema.publication_id,
        causal_unit_id: schema.causal_unit_id,
        phase: schema.phase,
        state: schema.state,
        dedupe_key: schema.dedupe_key,
        body: schema.body,
        body_ref: schema.body_ref,
        run_ref: schema.run_ref,
        turn_ref: schema.turn_ref,
        attempt_ref: schema.attempt_ref,
        reply_artifact_ref: schema.reply_artifact_ref,
        next_semantic_ref: schema.next_semantic_ref
      })

    publication
  end
end
