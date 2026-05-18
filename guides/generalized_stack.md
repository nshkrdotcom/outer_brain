# OuterBrain Generalized Stack Boundary

## Responsibility

OuterBrain owns semantic-session state, context assembly, prompt and strategy
shaping, semantic failure carriers, action-request synthesis, provisional/final
reply publication, restart replay, and quality/provenance evidence.

It does not own product workflow truth, connector SDKs, credential leases,
governance policy, lower lanes, or primitive persistence semantics.

## Public Interfaces

Primary package groups:

- `core/outer_brain_contracts`, `core/outer_brain_core`,
  `core/outer_brain_journal`, `core/outer_brain_runtime`,
  `core/outer_brain_persistence`, `core/outer_brain_restart_authority`, and
  `core/outer_brain_quality`;
- prompt, context, memory, guardrail, eval, token, artifact, and optimization
  packages;
- bridges for Citadel, typed domains, publication, review, and GroundPlane
  projections;
- `apps/host_surface` and proof examples.

## Dependency Rules

Allowed dependencies:

- Citadel contracts for authority and governed route facts;
- GroundPlane primitives for leases, refs, persistence posture, and projection
  helpers;
- AppKit or host-surface DTOs at the northbound edge;
- AITrace/export contracts for replay and evidence.

Forbidden dependencies:

- direct connector/runtime calls;
- product workflow mutation;
- policy decisions that should be made by Citadel;
- raw provider payloads or private prompt/context bodies in public receipts;
- unsupervised semantic workers or background tasks.

## Provider Vocabulary Zoning

Provider terms may describe external refusal, adapter unavailability, model
family metadata, or trace/evidence data. They must not select generic semantic
control flow. Routing should use stored manifest snapshots, action refs,
authority refs, and credential lease refs.

## Migration And Cleanup Ownership

OuterBrain cleanup work removes semantic runtime shortcuts, prompt/context
leaks, stale env access, old atomization hazards, unsupervised task runners,
and proof-only compatibility paths after the replacement semantic evidence is
covered by tests and StackLab receipts.
