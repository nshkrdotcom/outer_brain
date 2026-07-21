# OuterBrain Persistence

## Production contract

`core/outer_brain_persistence` owns PostgreSQL truth for semantic-session
leases, journal entries, recovery tasks, reply publications, immutable artifact
descriptors/payloads, and semantic-context provenance. The sole production profile is
`:durable_redacted`; missing, disabled, memory, and unknown profiles fail before
a repository child is selected.

Production hosts add this child to their supervision tree:

```elixir
{OuterBrain.Persistence.DurableSupervisor,
 profile: :durable_redacted,
 repo_options: [url: database_url]}
```

Hosts that start all repositories in an earlier supervision layer use
`repo_mode: :external`. That mode omits the Repo child and requires the
canonical Repo to be running before Bootstrap starts. A host can validate the
same database before starting its Repo layer by using a bounded temporary Repo:

```elixir
OuterBrain.Persistence.Store.preflight(
  profile: :durable_redacted,
  repo_mode: :temporary,
  repo_options: [url: database_url]
)
```

The supervisor starts `OuterBrain.Persistence.Repo` and then performs a live
preflight. Boot fails if the Repo is unavailable, a required table is absent,
or a package migration is pending. Preflight errors expose only safe error
classes, never connection strings or driver exception messages. A running host
may perform the same health check with:

```elixir
OuterBrain.Persistence.Store.preflight(
  profile: :durable_redacted,
  repo: OuterBrain.Persistence.Repo
)
```

## Semantic context and artifact boundaries

`Store.record_prompt_context/2` atomically records the content-addressed context
and prompt-manifest payloads, their secret-free descriptors, and matching
semantic provenance/lineage. `Store.publish_reply_continuation/2` atomically
records the normalized final reply, next context revision, publication, and a
safe journal fact. Exact replays are idempotent; reuse of an artifact, semantic,
publication, or idempotency reference with different facts fails closed. Tenant
scope is required on every write and read.

`Store.resolve_artifact_payload/3` requires exact tenant, reader, operation,
and authority-packet agreement. Artifact references are not bearer authority.

The semantic index contains only opaque semantic, provider, model, artifact,
run, turn, and provenance refs. Provider-native bodies, private reasoning,
credentials, signed object-store URLs, and credential-shaped metadata are
forbidden. Payloads are immutable and accessible only through the owner API;
locations remain opaque owner-authorized refs.

## Test boundary

Tests may start the canonical Repo directly against the isolated Docker
PostgreSQL fixture. That is a deterministic proof path, not a production
selector. There is no production memory, no-op, disabled, or fixture Repo.

Focused QC:

```bash
cd core/outer_brain_persistence
mix compile --warnings-as-errors
mix test test/outer_brain/persistence/store_boundary_test.exs \
  test/outer_brain/persistence/store_test.exs \
  test/outer_brain/persistence/semantic_failure_store_test.exs
```
