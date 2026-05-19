defmodule OuterBrain.Persistence.JournalMapper do
  @moduledoc false

  alias OuterBrain.Journal.Tables.SemanticJournalEntryRecord

  @spec from_schema(struct()) :: SemanticJournalEntryRecord.t()
  def from_schema(schema) do
    {:ok, entry} =
      SemanticJournalEntryRecord.new(%{
        entry_id: schema.entry_id,
        session_id: schema.session_id,
        causal_unit_id: schema.causal_unit_id,
        entry_type: schema.entry_type,
        recorded_at: schema.recorded_at,
        payload: schema.payload
      })

    entry
  end
end
