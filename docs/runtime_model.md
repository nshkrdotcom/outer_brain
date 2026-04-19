# Runtime Model

OuterBrain owns the durable semantic loop above Citadel.

The runtime loop is:

1. capture a raw turn in the semantic journal
2. acquire the semantic-session fence for the current epoch
3. build a context pack and strategy profile
4. validate model-selected work against the stored manifest snapshot
5. compile an action request or provider-neutral semantic failure carrier
6. publish provisional or final user-facing state
7. normalize lower facts into a single wake path
8. recover or reconcile from durable evidence after restart

Phase 4 semantic activities return normalized semantic results, not provider
payloads. Workflow history may carry semantic refs, context hashes, provenance
refs, diagnostics refs, validation state, retry/terminal class, and bounded
routing facts such as review requirement, score, confidence band, risk band, and
retry class. Raw prompts, provider-native bodies, raw context packs, artifacts,
and execution logs stay in Outer Brain or claim-check storage.

Citadel remains the policy kernel beneath this layer, and `jido_integration`
remains the durable lower execution owner.

Semantic failures are deterministic runtime facts at this layer. OuterBrain
normalizes ambiguous route selection, stale context/manifest state, adapter
unavailability, provider refusal/filtering, semantic loops, and budget
exhaustion into `OuterBrain.Contracts.SemanticFailure`. The carrier preserves
tenant, semantic-session, causal-unit, request-trace, provenance, optional
context hash, and optional provider reference without making provider-specific
fields part of Mezzanine lifecycle logic.

Reply publication is idempotent by durable `dedupe_key`. Restart replay may
refresh the stored body/state for the same semantic publication but must not
create a second user-visible publication row.
