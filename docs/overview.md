# Overview

OuterBrain is the semantic-runtime workspace that sits above Citadel and below
host surfaces.

It owns the language-facing work that should not live in the deterministic
policy kernel:

- raw ingress journaling
- semantic-frame reduction
- context-pack construction
- tool-manifest snapshots compiled from typed routes
- quality checkpoints
- provisional and final reply publication
- restart-safe semantic recovery

The repo is intentionally split into contracts, journal, prompting, quality,
runtime, restart authority, bridges, and proving examples so semantic authority,
policy authority, and lower durable execution truth stay separated.
