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
- `./examples/console_chat/mix.exs`: Console-chat smoke example for the OuterBrain workspace
- `./examples/direct_citadel_action/mix.exs`: Direct action-compilation smoke example for the OuterBrain workspace
- `./mix.exs`: Workspace root for the OuterBrain semantic-runtime monorepo

# AGENTS.md

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
