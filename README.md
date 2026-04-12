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

OuterBrain is a starter repository for the semantic runtime layer above Citadel.

The repository is intentionally light for now. It exists to give the emerging runtime a clear home for semantic journaling, context assembly, intent synthesis, reply publication, and the restart-safe seams that sit above the policy kernel.

## Scope

- raw input normalization
- semantic state and journaling
- context assembly
- structured intent synthesis
- reply publication and downstream follow-up

## Status

Early starter repository. The precise runtime model, package split, and proving examples are still being refined.

## Development

The project targets Elixir `~> 1.19` and Erlang/OTP `28`. The pinned toolchain lives in [`.tool-versions`](./.tool-versions).

```bash
mix deps.get
mix test
```

## Documentation

- [docs/overview.md](./docs/overview.md)
- [docs/runtime_model.md](./docs/runtime_model.md)
- [docs/integration_surface.md](./docs/integration_surface.md)
- [CHANGELOG.md](./CHANGELOG.md)

## License

MIT. See [LICENSE](./LICENSE).
