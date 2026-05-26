# OuterBrain Context ABI

OuterBrain owns the Context ABI data model and semantic artifact references for
the NSHKR stack. The public surface is the `core/context_abi` package, with
prompt rendering owned by `core/outer_brain_prompting`.

## Owned Outputs

- `OuterBrain.ContextABI.ContextUnit` for bounded context inputs.
- `OuterBrain.ContextABI.ContextPacket` for admitted packet facts and packet
  hashes.
- `OuterBrain.Prompting.ContextRenderer` for sealed prompt artifact refs,
  provider payload refs, and payload hashes.
- Failure reason codes under `OuterBrain.ContextABI.Failure`.

## Boundary Rules

OuterBrain does not execute models, grant authority, promote optimization
candidates, or own product projections. Mezzanine holds the rendered prompt
handoff as a `Mezzanine.AIExecution.RenderResult` and passes only refs and
hashes to Jido Integration.

Context packet construction validates ref schemes before canonical hashing:
tenant refs, user request refs, system instruction refs, memory refs, budget
refs, model class refs, route policy refs, and trace refs must use their
accepted scheme families. Invalid schemes fail before the packet hash is
claimed.

Raw prompts and raw memory bodies must not cross product, authority, workflow,
or model-runtime boundaries. Use artifact refs, payload refs, packet hashes,
trace refs, and bounded failure reason codes.

## Local QC

```bash
mix ci
```

StackLab proof of the Context ABI path is owned by StackLab. OuterBrain remains
responsible for its package tests, canonical hashing, renderer validation, and
redaction posture.
