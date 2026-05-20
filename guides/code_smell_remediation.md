# OuterBrain Code Smell Remediation

This guide records the repo-local implementation posture after the GN-TEN code
smell remediation pass.

## What Changed

- Memory and artifact contracts are split into narrower shapes so semantic
  runtime values do not become catch-all structs.
- Persistence store responsibilities are separated across query, mapping, and
  policy-default modules.
- Lease registry behavior is moved toward supervised ownership instead of an
  Agent-backed mirror.
- Private ETS caches are documented as local lifecycle state and not durable
  truth.
- Docker and proof polling helpers use named readiness boundaries.

## Maintainer Rules

- OuterBrain owns semantic facts, prompt/context assembly, restart-safe
  semantic state, and semantic evidence.
- It must not own provider memory, product behavior, lower execution, or
  authority decisions.
- Do not introduce raw sleeps, hidden mutable globals, or provider dispatch in
  semantic core modules.

## QC

Use the repo root gate:

```bash
mix ci
```
