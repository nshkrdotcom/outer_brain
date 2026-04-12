# Integration Surface

This repository integrates with:

- Citadel for structured policy decisions
- `jido_domain` for typed route input that becomes a durable manifest snapshot
- `jido_integration` for durable lower runtime facts and restart authority below
  the semantic layer
- `ground_plane` projection helpers through a bridge seam
- host shells and APIs through the `host_surface` app

The bridge packages in this workspace keep those seams explicit and replayable.
