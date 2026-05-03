# OuterBrain Prompting

Context-pack construction, strategy profiles, tool gating, and replayable prompt
assembly helpers.

Context adapters are provider-neutral read surfaces. They receive a bounded
read-only request plus runtime binding configuration and return
provenance-bearing fragments. The context pack records source reports,
adapter keys, fragment counts, staleness, and provenance; adapter memory or RAG
state is never platform truth.

Governed context packs require an explicit `:adapter_registry` option. The
standalone application-env adapter registry remains available only when callers
pass `standalone_application_env?: true`, so ambient app env cannot select a
memory or RAG adapter for governed prompt construction.
