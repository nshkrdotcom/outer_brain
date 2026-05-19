# OuterBrain AI Artifact Contracts

Ref-only adaptive artifact contracts for prompt, role, candidate, router,
verifier, eval, replay, provider, endpoint, promotion, and rollback identity.
The package never carries raw prompts, provider payloads, model outputs, memory
bodies, credential material, or non-OuterBrain skill ownership.

Use `OuterBrain.AIArtifactContracts.build_ref_set/1` to construct the composed
proof/reporting view. The returned `RefSet` groups refs by concern:
`prompt_refs`, `optimization_refs`, `evaluation_refs`, `routing_refs`, and
`model_refs`. Use `policy_artifact_ref/1` for policy artifacts that carry
source, lineage, rollback, trace, and redaction refs.
