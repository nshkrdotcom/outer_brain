# Runtime Model

OuterBrain owns the durable semantic loop above Citadel.

The runtime loop is:

1. capture a raw turn in the semantic journal
2. acquire the semantic-session fence for the current epoch
3. build a context pack and strategy profile
4. validate model-selected work against the stored manifest snapshot
5. compile an action request or clarification
6. publish provisional or final user-facing state
7. normalize lower facts into a single wake path
8. recover or reconcile from durable evidence after restart

Citadel remains the policy kernel beneath this layer, and `jido_integration`
remains the durable lower execution owner.
