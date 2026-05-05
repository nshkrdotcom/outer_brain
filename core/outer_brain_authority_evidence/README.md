# OuterBrain Authority Evidence

Phase 12 package for tenant-scoped prompt provenance, semantic evidence,
privacy class, suppression state, memory fact refs, and redacted authority
evidence.

This package does not issue leases, read provider env vars, call provider SDKs,
or materialize credentials. It records ref-only facts for AppKit, Mezzanine,
AITrace, and StackLab.

QC:

```bash
mix test
mix format --check-formatted
mix compile --warnings-as-errors
```
