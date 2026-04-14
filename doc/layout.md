# Workspace Layout

The repo is a non-umbrella workspace root.

Key groups:

- `core/outer_brain_contracts`
- `core/outer_brain_journal`
- `core/outer_brain_core`
- `core/outer_brain_prompting`
- `core/outer_brain_quality`
- `core/outer_brain_runtime`
- `core/outer_brain_restart_authority`
- `bridges/*`
- `apps/host_surface`
- `examples/*`

This split keeps the semantic runtime explainable without turning the root repo
into one large opaque application.
