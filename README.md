<p align="center">
  <img src="assets/outer_brain.svg" width="200" height="200" alt="OuterBrain logo" />
</p>

<p align="center">
  <a href="https://github.com/nshkrdotcom/outer_brain/actions/workflows/ci.yml">
    <img alt="GitHub Actions Workflow Status" src="https://github.com/nshkrdotcom/outer_brain/actions/workflows/ci.yml/badge.svg" />
  </a>
  <a href="https://github.com/nshkrdotcom/outer_brain/blob/main/LICENSE">
    <img alt="License: MIT" src="https://img.shields.io/badge/license-MIT-0b0f14.svg" />
  </a>
</p>

# OuterBrain

OuterBrain is the provider-neutral semantic-runtime gateway above Citadel.

It owns durable semantic-session truth, tool-manifest snapshots, prompt and
strategy shaping, semantic quality checkpoints, live session fencing,
provider-neutral semantic failure carriers, and restart-safe reply publication.
It does not own provider memory, RAG engines, or model-specific cognition as
platform truth.

## Scope

- raw input normalization
- durable semantic state and journaling
- context assembly
- prompt and strategy shaping
- provider-neutral semantic failure normalization
- normalized semantic activity contracts with bounded routing facts
- semantic context provenance, duplicate suppression, and redaction evidence
- structured action-request synthesis
- provisional and final reply publication
- restart-safe downstream follow-up

## Status

Active workspace buildout. The repo uses a non-umbrella workspace layout with
core packages, a dedicated raw-Ecto persistence layer, bridges, a host surface,
and proving examples.

## Development

The project targets Elixir `~> 1.19` and Erlang/OTP `28`. The pinned toolchain
lives in `.tool-versions`.

```bash
mix deps.get
mix ci
```

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

## Documentation

- `docs/overview.md`
- `docs/layout.md`
- `docs/runtime_model.md`
- `docs/integration_surface.md`
- `CHANGELOG.md`

This project is licensed under the MIT License.
(c) 2026 nshkrdotcom. See `LICENSE`.

## Temporal developer environment

Temporal runtime development is managed from `/home/home/p/g/n/mezzanine`
through the repo-owned `just` workflow. Do not start ad hoc Temporal processes
or rely on the `temporal` CLI as the implementation runbook.

## Native Temporal development substrate

Temporal runtime development is managed from `/home/home/p/g/n/mezzanine` through the repo-owned `just` workflow, not by manually starting ad hoc Temporal processes.

Use:

```bash
cd /home/home/p/g/n/mezzanine
just dev-up
just dev-status
just dev-logs
just temporal-ui
```

Expected local contract: `127.0.0.1:7233`, UI `http://127.0.0.1:8233`, namespace `default`, native service `mezzanine-temporal-dev.service`, persistent state `~/.local/share/temporal/dev-server.db`.
