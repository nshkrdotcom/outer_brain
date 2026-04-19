# Domain Bridge

Compiles typed route catalogs into durable tool-manifest snapshots and lowers
semantic turn selections into typed domain requests.

Semantic selection failures are emitted as
`OuterBrain.Contracts.SemanticFailure` carriers. The bridge does not expose
provider-specific memory or model errors as control-flow primitives; it
normalizes ambiguous route selection, stale manifests, and invalid semantic
output into deterministic failure kinds that AppKit and Mezzanine can preserve
without interpreting provider internals.
