# OuterBrain Persistence

Raw Ecto/Postgres durability layer for restart-critical semantic-runtime state.

Stage-1 durable tables:

- `semantic_session_leases`
- `semantic_journal_entries`
- `recovery_tasks`
- `reply_publications`

This package owns the canonical write path for those rows. In-memory runtime
state may mirror hot rows, but it does not own truth.

Semantic failure carriers are recorded as idempotent
`semantic_journal_entries` with `entry_type = "semantic_failure"` and payloads
encoded through `OuterBrain.Contracts.SemanticFailure`. Reply publication
writes are idempotent by `dedupe_key`, so restart replay can update the durable
publication row without creating a second user-visible publication.

Phase 7 persistence writes preserve the posture selected by the contract layer
while keeping raw prompt and provider payload persistence disabled. Memory-mode
callers keep using ref-only contract records; this package remains the explicit
raw Ecto/Postgres durable opt-in and is not required for default semantic
runtime execution.

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.
