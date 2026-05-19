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

Phase 7 runtime leases, fences, session owners, and stream-state helpers carry
memory-default persistence posture. The posture is evidence only: debug tap
failure is non-mutating, and publication or semantic-session state transitions
do not depend on durable storage being available.

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.
