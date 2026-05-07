# OuterBrain Memory Contracts

Frozen governed-memory contract structs for memory refs, write and query
intents, evidence refs, redaction policy, memory scope, access reasons, and
context-budget decisions.

The package is pattern-engine-free and carries refs, hashes, bounded excerpts, and
policy names only. Raw memory bodies are rejected at construction boundaries.

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.
