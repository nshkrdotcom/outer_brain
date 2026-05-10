# Monorepo Project Map

- `./apps/host_surface/mix.exs`: Minimal host-facing semantic runtime entrypoint for the OuterBrain workspace
- `./bridges/citadel_bridge/mix.exs`: Structured policy bridge from action requests into Citadel envelopes
- `./bridges/domain_bridge/mix.exs`: Manifest compilation bridge from typed routes into OuterBrain
- `./bridges/ground_plane_projection_bridge/mix.exs`: Projection bridge from semantic runtime records into GroundPlane-style shapes
- `./bridges/publication_bridge/mix.exs`: Reply publication bridge for provisional and final semantic output
- `./bridges/review_bridge/mix.exs`: Operator-facing review bundle bridge for quality checkpoints
- `./core/outer_brain_contracts/mix.exs`: Pure semantic-runtime contracts for the OuterBrain workspace
- `./core/outer_brain_core/mix.exs`: Semantic reducers and action-request compilation for OuterBrain
- `./core/outer_brain_journal/mix.exs`: Semantic journal structures and transaction helpers for OuterBrain
- `./core/outer_brain_persistence/mix.exs`: Raw Ecto/Postgres durability layer for OuterBrain restart-critical state
- `./core/outer_brain_prompting/mix.exs`: Prompt packs, strategy profiles, and manifest gating for OuterBrain
- `./core/outer_brain_quality/mix.exs`: Semantic quality checkpoint and critic helpers for OuterBrain
- `./core/outer_brain_restart_authority/mix.exs`: Restart scan and reconcile helpers for OuterBrain
- `./core/outer_brain_runtime/mix.exs`: Live session ownership, wake coordination, and streaming control for OuterBrain
- `./core/ai_artifact_contracts/mix.exs`: Ref-only adaptive artifact identity contracts
- `./core/optimization_artifact_store/mix.exs`: Ref-only adaptive optimization artifact graph history
- `./examples/console_chat/mix.exs`: Console-chat smoke example for the OuterBrain workspace
- `./examples/direct_citadel_action/mix.exs`: Direct action-compilation smoke example for the OuterBrain workspace
- `./mix.exs`: Workspace root for the OuterBrain semantic-runtime monorepo

# AGENTS.md

## Onboarding

Read `ONBOARDING.md` first for the repo's one-screen ownership, first command,
and proof path.

## Temporal developer environment

Temporal CLI is implicitly available on this workstation as `temporal` for local durable-workflow development. Do not make repo code silently depend on that implicit machine state; prefer explicit scripts, documented versions, and README-tracked ergonomics work.

## Native Temporal development substrate

When Temporal runtime behavior is required, use the stack substrate in `/home/home/p/g/n/mezzanine`:

```bash
just dev-up
just dev-status
just dev-logs
just temporal-ui
```

Do not invent raw `temporal server start-dev` commands for normal work. Do not reset local Temporal state unless the user explicitly approves `just temporal-reset-confirm`.

## Dependency Sources

- Dependency source selection is handled by `build_support/dependency_sources.exs` and `build_support/dependency_sources.config.exs`.
- Local dependency overrides use `.dependency_sources.local.exs`.
- Dependency source selection must not use environment variables.
- Same-repo workspace package paths may stay in their local `mix.exs` files; cross-repo dependencies that need fallback behavior belong in the dependency-source manifest.
- Weld checks helper drift, dependency-source manifests, clone/publish checks, and publish order for this repo; keep the committed dependency on the released Hex Weld line.

## Runtime Env

- Runtime application code under `lib/**`, package `lib/**`, example `lib/**`, and Mix task modules must not call direct OS env APIs such as `System.get_env`, `System.fetch_env`, `System.put_env`, or `System.delete_env`.
- Runtime/deployment env reads belong in `config/runtime.exs` or a `Config.Provider`.
- Mix tasks, examples, and harnesses should accept explicit flags, app config, or caller-supplied env maps instead of reading or mutating process env.

<!-- gn-ten:repo-agent:start repo=outer_brain source_sha=ab276c0640772b73065ab12bf05d77be51f1bb67 -->
# outer_brain Agent Instructions Draft

## Owns

- Semantic runtime.
- Raw turn capture.
- Context-pack construction.
- Prompt and strategy shaping.
- Tool-manifest snapshots.
- Semantic quality checks and restart-safe publication.

## Does Not Own

- Policy authority.
- Durable review truth.
- Provider credential lifecycle.
- Direct lower execution.
- Product UX.

## Allowed Dependencies

- Citadel DomainSurface contracts.
- GroundPlane refs.
- Mezzanine memory/projection refs only through public contracts.
- AITrace trace refs.

## Forbidden Imports

- Execution Plane lower runtimes.
- Provider SDK execution clients as platform truth.
- Product modules.

## Verification

- `mix ci`
- Semantic failure, restart durability, and context provenance tests.

## Escalation

If a model-selected tool needs execution, route through Citadel and Jido
Integration. Do not execute directly.
<!-- gn-ten:repo-agent:end -->

## Blitz 0.3.0 operational note

Root workspace Blitz uses published Hex `~> 0.3.0` by default; `.blitz/` is committed compact impact state after green QC. Source and `mix.exs` changes cascade through reverse workspace dependencies; docs-only changes should stay owner-local.
