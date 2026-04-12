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

OuterBrain is the semantic-runtime workspace above Citadel.

It owns semantic journals, tool-manifest snapshots, prompt and strategy shaping,
semantic quality checkpoints, live session fencing, and restart-safe reply
publication.

## Scope

- raw input normalization
- semantic state and journaling
- context assembly
- prompt and strategy shaping
- structured action-request synthesis
- provisional and final reply publication
- restart-safe downstream follow-up

## Status

Active workspace buildout. The repo uses a non-umbrella workspace layout with
core packages, bridges, a host surface, and proving examples.

## Development

The project targets Elixir `~> 1.19` and Erlang/OTP `28`. The pinned toolchain
lives in `.tool-versions`.

```bash
mix deps.get
mix ci
```

## Documentation

- `docs/overview.md`
- `docs/layout.md`
- `docs/runtime_model.md`
- `docs/integration_surface.md`
- `CHANGELOG.md`

This project is licensed under the MIT License.
(c) 2026 nshkrdotcom. See `LICENSE`.
