# OuterBrain Runtime

Live semantic-session fencing, wake coordination, and stream-state helpers.

The canonical lease truth lives in `outer_brain_persistence`; runtime registry
state is only the hot mirror used by active owners.

`OuterBrain.Runtime.LeaseRegistry` is a supervised GenServer mirror. It is safe
for active runtime ownership checks, but it is not durable truth. Reads that
need operational evidence should use `current_fence_with_posture/3`, which
returns fresh, stale, or missing mirror posture. Stale mirror reads fail closed;
callers can reload from the canonical persistence store before acting.

The registry emits telemetry for lease acquire, renew, expire, and release
events under `[:outer_brain, :runtime, :lease_registry, event]`.

`OuterBrain.Runtime.SessionOwner.acquire/6` always acquires through the
canonical PostgreSQL store and carries `:durable_redacted` posture. The
test-only `acquire_with_store/7` seam accepts fixture modules that exist only in
the test build. No production API selects a memory or no-op lease store.

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.
