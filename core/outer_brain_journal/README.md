# OuterBrain Journal

Table-shaped semantic journal rows and lightweight projection helpers.

Restart-critical canonical writes land in `outer_brain_persistence`; the
in-memory journal helpers remain useful for pure reducers and fixture assembly.

Phase 7 journal rows carry persistence posture for semantic-session leases,
semantic journal entries, and reply publications. Memory/default posture is
ref-only; durable-redacted posture changes store and receipt refs without
allowing raw prompt or raw provider payload persistence.

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.
