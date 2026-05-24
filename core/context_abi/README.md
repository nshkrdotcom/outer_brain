# OuterBrain Context ABI

Ref-only Context ABI contracts for governed model execution.

This package owns the MVP context packet surface, deterministic packet hashes,
context unit validation, context packet receipts, and owner-local failure
reason-code shape. It does not render provider-native payloads, authorize
restricted context, execute models, or persist workflow truth.

The package uses `GroundPlane.Boundary.Codec` through GroundPlane contracts for
canonical boundary encoding and `sha256:` digest generation.
