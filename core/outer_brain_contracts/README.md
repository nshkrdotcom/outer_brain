# OuterBrain Contracts

Pure contracts for fenced semantic sessions, manifest snapshots, action
requests, runtime facts, semantic failure carriers, and reply publication state.

`OuterBrain.Contracts.SemanticFailure` is the provider-neutral failure carrier
used at the semantic-runtime boundary. It carries deterministic failure kind,
retry class, tenant/session/trace/causal identity, provenance, optional provider
reference, and operator-facing message without allowing Mezzanine or AppKit to
branch on provider-specific semantics.
