# OuterBrain Authority Evidence

Phase 12 package for tenant-scoped prompt provenance, semantic evidence,
privacy class, suppression state, memory fact refs, and redacted authority
evidence.

This package does not issue leases, read provider env vars, call provider SDKs,
or materialize credentials. It records ref-only facts for AppKit, Mezzanine,
AITrace, and StackLab.

Phase 7 authority evidence carries memory-default persistence posture and
rejects raw prompt, provider payload, token, credential, and auth material. The
posture is runtime evidence only and does not authorize semantic effects.

QC:

```bash
mix test
mix format --check-formatted
mix compile --warnings-as-errors
```

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.
