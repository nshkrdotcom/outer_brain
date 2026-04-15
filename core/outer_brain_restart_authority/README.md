# OuterBrain Restart Authority

Restart scan and reconcile logic for provisional publication, stale manifests,
and lower fact follow-up.

The restart scan reads durable recovery tasks and reply publication state; it
does not treat in-memory journal state as canonical recovery truth.
