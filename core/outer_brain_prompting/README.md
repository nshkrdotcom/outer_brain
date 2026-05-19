# OuterBrain Prompting

Context-pack construction, strategy profiles, tool gating, and replayable prompt
assembly helpers.

Context adapters are provider-neutral read surfaces. They receive a bounded
read-only request plus runtime binding configuration and return
provenance-bearing fragments. The context pack records source reports,
adapter keys, fragment counts, staleness, and provenance; adapter memory or RAG
state is never platform truth.

Governed context packs require an explicit `:adapter_registry` option. The
standalone adapter path uses the same explicit registry option, so ambient app
env cannot select a memory or RAG adapter for governed prompt construction.

Phase 7 prompt and context packs carry `OuterBrain.Contracts.PersistencePosture`
as redacted evidence. Context fragments reject raw prompt/provider payload keys,
and memory/default or durable-redacted posture changes storage refs without
changing prompt assembly, adapter selection, or provenance semantics.

Recall cache and sidecar index tables are caller-owned private ETS helpers.
They are non-authoritative, live only for the owner process lifetime, and store
fragment refs/hashes rather than memory payloads. Long-lived production cache
ownership must move behind a supervised owner before it can make restart or
durability claims.

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.
