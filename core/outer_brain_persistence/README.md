# OuterBrain Persistence

Raw Ecto/Postgres durability layer for restart-critical semantic-runtime state.

Stage-1 durable tables:

- `semantic_session_leases`
- `semantic_journal_entries`
- `recovery_tasks`
- `reply_publications`

This package owns the canonical write path for those rows. In-memory runtime
state may mirror hot rows, but it does not own truth.
