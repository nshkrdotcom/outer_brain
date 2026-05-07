# OuterBrain Restart Authority

Restart scan and reconcile logic for provisional publication, stale manifests,
and lower fact follow-up.

The restart scan reads durable recovery tasks and reply publication state; it
does not treat in-memory journal state as canonical recovery truth.

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.
