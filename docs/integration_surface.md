# Integration Surface

This repository integrates with:

- Citadel for structured policy decisions
- `jido_domain` for typed route input that becomes a durable manifest snapshot
- `jido_integration` for durable lower runtime facts and restart authority below
  the semantic layer
- `ground_plane` projection helpers through a bridge seam
- host shells and APIs through the `host_surface` app

The bridge packages in this workspace keep those seams explicit and replayable.

The welded `outer_brain_contracts` artifact is tracked through the prepared
bundle flow:

```bash
mix release.prepare
mix release.track
mix release.archive
```

`mix release.track` updates the orphan-backed
`projection/outer_brain_contracts` branch so downstream repos can pin a real
generated-source ref before any formal release boundary exists.

## Current Lowering Path

The semantic lowering path is now:

- turn input is selected onto a typed route by `OuterBrain.Core.TurnSelector`
- route metadata is compiled into a stable tool and route manifest snapshot by
  `OuterBrain.Bridges.ManifestCompiler`
- semantic submission into the typed domain layer is owned by
  `OuterBrain.Bridges.DomainSubmission`
- the lower typed route then flows through `jido_domain`, the public
  `Citadel.HostIngress` seam, and the real `jido_integration` ingress path

This keeps `outer_brain` responsible for semantic selection and packaging, not
for durable lower-truth ownership.
