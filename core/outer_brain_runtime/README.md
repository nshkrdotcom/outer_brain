# OuterBrain Runtime

Live semantic-session fencing, wake coordination, and stream-state helpers.

The canonical lease truth lives in `outer_brain_persistence`; runtime registry
state is only the hot mirror used by active owners.

Phase 7 runtime leases, fences, session owners, and stream-state helpers carry
memory-default persistence posture. The posture is evidence only: debug tap
failure is non-mutating, and publication or semantic-session state transitions
do not depend on durable storage being available.

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.
