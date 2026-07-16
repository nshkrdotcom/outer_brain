# OuterBrain Persistence

Raw Ecto/Postgres durability layer for restart-critical semantic-runtime state.

Canonical durable tables include:

- `semantic_session_leases`
- `semantic_journal_entries`
- `recovery_tasks`
- `reply_publications`
- `outer_brain_artifact_descriptors`
- `outer_brain_semantic_contexts`

This package owns the canonical write path for those rows. In-memory runtime
state may mirror hot rows, but it does not own truth.

Semantic failure carriers are recorded as idempotent
`semantic_journal_entries` with `entry_type = "semantic_failure"` and payloads
encoded through `OuterBrain.Contracts.SemanticFailure`. Reply publication
writes are idempotent by `dedupe_key`, so restart replay can update the durable
publication row without creating a second user-visible publication.

Semantic-context writes atomically persist a secret-free
`GroundPlane.Contracts.ArtifactDescriptor` and immutable
`OuterBrain.Contracts.SemanticContextProvenance`. The PostgreSQL full-text
index covers opaque semantic, provider, model, artifact, and provenance refs;
it never indexes raw prompt or provider bodies.

Production hosts supervise
`{OuterBrain.Persistence.DurableSupervisor, profile: :durable_redacted,
repo_options: [...]}`. This is the only production composition: it starts the
canonical Repo and fails startup unless the live schema has every required
table and migration. Missing, disabled, and memory profiles are rejected.
Deterministic tests may start `OuterBrain.Persistence.Repo` directly against an
isolated container; no test memory repository is compiled into production.

Dockerized Postgres test support uses a bounded readiness awaiter. Startup
failures include the last failed probe output and remove the temporary
container before raising.

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.
