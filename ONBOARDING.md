# outer_brain Onboarding

Read `AGENTS.md` first; the managed gn-ten section is the repo contract.
`CLAUDE.md` must stay a one-line compatibility shim containing `@AGENTS.md`.

## Owns

Semantic runtime, raw turn capture, context packs, prompt/strategy shaping,
tool-manifest snapshots, semantic quality checks, and restart-safe publication.

## Does Not Own

Policy authority, durable review truth, provider credential lifecycle, direct
lower execution, or product UX.

## First Task

```bash
cd /home/home/p/g/n/outer_brain
mix ci
cd /home/home/p/g/n/stack_lab
mix gn_ten.plan --repo outer_brain
```

## Proofs

StackLab owns assembled proof. Use `/home/home/p/g/n/stack_lab/proof_matrix.yml`
and `/home/home/p/g/n/stack_lab/docs/gn_ten_proof_matrix.md`.

## Common Changes

Route executable intent through Citadel/JidoIntegration contracts. Keep raw
prompts, model payloads, and private reasoning out of public receipts.
