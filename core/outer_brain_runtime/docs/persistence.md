# OuterBrain Runtime Persistence

OuterBrain runtime owns live session processes and a supervised hot lease
mirror. PostgreSQL truth remains in `outer_brain_persistence`.

Production `SessionOwner.acquire/6` always writes the canonical persistence
store with `:durable_redacted` posture before updating the mirror. It exposes
no memory, disabled, no-op, or alternate-store option. Deterministic tests use
`acquire_with_store/7` with fixture modules compiled under `test/`; those
fixtures do not exist in production releases.

`LeaseRegistry.current_fence_with_posture/3` distinguishes `:mirror_fresh`,
`:mirror_stale`, and `:missing`. Stale reads fail closed. Call
`LeaseRegistry.reload_from_canonical/4` to repopulate the mirror from
PostgreSQL, then re-read the fence. The registry emits acquire, renew, expire,
and release telemetry under
`[:outer_brain, :runtime, :lease_registry, event]`.

The production host must supervise
`OuterBrain.Persistence.DurableSupervisor` before starting runtime consumers.
That child fails boot unless the canonical Repo and every required migration
are present. Raw prompts, provider payloads, credentials, and signed object
locations never belong in lease or mirror state.
