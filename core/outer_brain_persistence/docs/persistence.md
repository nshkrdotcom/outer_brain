# OuterBrain Persistence

## Production contract

`core/outer_brain_persistence` owns PostgreSQL truth for semantic-session
leases, journal entries, recovery tasks, reply publications, artifact
descriptors, and semantic-context provenance. The sole production profile is
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

`Store.record_semantic_context/3` atomically records an immutable,
secret-free `GroundPlane.Contracts.ArtifactDescriptor` and the matching
`OuterBrain.Contracts.SemanticContextProvenance`. Exact replays are idempotent;
reuse of an artifact, semantic, or idempotency reference with different facts
fails closed. Tenant scope is required on every write and read.

The semantic index contains only opaque semantic, provider, model, artifact,
and provenance refs. Raw prompts, provider bodies, signed object-store URLs,
credentials, and credential-shaped metadata are forbidden. Object locations
remain opaque owner-authorized refs.

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
