# OuterBrain Contracts

Pure contracts for fenced semantic sessions, manifest snapshots, action
requests, runtime facts, semantic failure carriers, reply publication state, and
Phase 4 semantic integrity payloads.

`OuterBrain.Contracts.SemanticGatewayContract` is the Phase 6
`SemanticGatewayContract.v1` owner aggregate. It composes the existing semantic
provenance, provider-neutral failure, read-only context adapter, reply
publication dedupe, suppression visibility, privacy redaction, bounded evidence,
and restart/replay refs required to close the Phase 5PRELIM `P5P-002`
handoff. It rejects raw payload evidence, provider-SDK mock proof, and
lower-runtime-only proof without OuterBrain owner evidence.

`OuterBrain.Contracts.SemanticFailure` is the provider-neutral failure carrier
used at the semantic-runtime boundary. It carries deterministic failure kind,
retry class, tenant/session/trace/causal identity, provenance, optional provider
reference, and operator-facing message without allowing Mezzanine or AppKit to
branch on provider-specific semantics.

`OuterBrain.Contracts.PersistencePosture` is the Phase 7 ref-only storage and
capture evidence contract. Semantic sessions, prompt/context provenance,
failure carriers, reply publications, duplicate suppression, and authority
evidence default to memory/ref-only posture and always mark raw prompt and raw
provider payload persistence as false.

## Phase 4 Semantic Integrity Contracts

Milestone 7 adds the release-grade contracts that keep Outer Brain a
provider-neutral semantic gateway instead of a provider-memory or workflow
payload engine:

- `OuterBrain.SemanticContextProvenance.v1` is implemented by
  `OuterBrain.Contracts.SemanticContextProvenance`. It requires tenant,
  installation, workspace, project, environment, actor, resource, authority,
  idempotency, trace, semantic refs, provider/model refs, prompt/context hashes,
  claim-check refs, normalizer version, provenance refs, and redaction policy.
- `OuterBrain.SemanticDuplicateSuppression.v1` is implemented by
  `OuterBrain.Contracts.SemanticDuplicateSuppression`. It requires deterministic
  semantic idempotency, duplicate lineage, routing-fact hash, publication ref,
  reason code, and operator-visible suppression evidence.
- `OuterBrain.ContextAdapterReadOnly.v1` is implemented by
  `OuterBrain.Contracts.ContextAdapterReadOnly`. It allows explicit read sets
  and denied write resources, and rejects any mutation permission grant.
- `OuterBrain.SemanticActivityNormalized.v1` is implemented by
  `OuterBrain.Contracts.SemanticActivityNormalized`. It returns compact workflow
  history payloads containing semantic refs, context hash, provenance refs,
  diagnostics refs, validation state, retry/terminal class, and bounded routing
  facts. Raw prompts, provider-native bodies, context packs, artifacts, and
  execution logs are rejected.
- `OuterBrain.SemanticActivityPayloadBoundary.v1` is implemented by
  `OuterBrain.Contracts.NormalizedSemanticResult` for Phase 4 durable workflow
  activity returns. It preserves the same normalization and quarantine rules
  while exposing the M29 workflow-facing contract name.
- `Platform.PrivacyRedactionFixture.v1` is implemented by
  `OuterBrain.Contracts.PrivacyRedactionFixture` for the Outer Brain side of
  public DTO, incident, and search-attribute redaction proof.
- `Platform.SuppressionVisibility.v1` is implemented by
  `OuterBrain.Contracts.SuppressionVisibility` for the Outer Brain suppression
  producer side of operator-visible suppression and quarantine proof.

Semantic activities must return workflow-visible routing facts such as
`review_required`, `semantic_score`, `confidence_band`, `risk_band`,
`schema_validation_state`, `normalization_warning_count`,
`semantic_retry_class`, `terminal_class`, and `review_reason_code`. Returning
only a claim-check ref is rejected when workflow routing depends on those facts.

## Persistence Documentation

See `docs/persistence.md` for tiers, defaults, adapters, unsupported selections, config examples, restart claims, durability claims, debug sidecar behavior, redaction guarantees, migration or preflight behavior, and no-bypass scope when applicable.
