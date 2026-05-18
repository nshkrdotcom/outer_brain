# OuterBrain QC And Operations

## Local Commands

```bash
mix deps.get
mix ci
```

Use package-local tests for focused semantic, persistence, prompt, or bridge
changes, then root `mix ci` before commit.

## Scanner And Proof Obligations

OuterBrain changes must keep these obligations green:

- restart-durability and semantic-session tests;
- prompt/context redaction and provenance tests;
- StackLab `examples/outer_brain_restart_durability` and session-lineage proof
  coverage when semantic replay behavior changes;
- no Regex usage in touched code/tests;
- no dynamic atom construction from runtime input;
- supervised ownership for any process, worker, session fence, publication
  runner, or background task.

## Secrets And Live Providers

OuterBrain does not read GitHub or Linear secrets. Semantic evidence may refer
to provider facts through lower receipts, but credential material stays in Jido
Integration leases and product/live commands.

If a proof command reaches GitHub or Linear through an OuterBrain-backed product
path, prefix it with:

```bash
~/scripts/with_bash_secrets
```

## Tenant, Observability, And Replay

Every semantic journal, publication, failure carrier, and quality evidence ref
must carry tenant/session/causal-unit scope. Public evidence should expose
redacted refs, not raw prompt, context, provider, or private reasoning bodies.
AITrace receives semantic lineage events needed for replay.

## Documentation Checks

After doc edits, run:

```bash
test -f README.md
find guides -maxdepth 1 -type f -name '*.md' -print | sort
git diff --check -- README.md guides
```
