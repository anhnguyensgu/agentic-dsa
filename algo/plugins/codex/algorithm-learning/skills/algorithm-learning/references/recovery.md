# Recovery and handoff

Call `session_resume` after context loss or a host switch. Compare the current source hash with the stored attempt and tested snapshots. If files changed, rerun before describing prior evidence as current. Continue the recorded next action and unanswered question instead of restarting onboarding.

Each checkpoint writes a compact JSON handoff and a learner-readable Markdown view under `.algo/learning/sessions/<session-id>/`. Event replay is authoritative if a handoff view is stale or missing.

For provider timeouts, rate limits, expired sessions, or response changes, preserve the attempt and job. Treat local tooling failure as no learning outcome. Use the provider's existing login flow without exposing credentials to the tutor.

If sending may have succeeded but no remote ID was captured, keep `submission_outcome_unknown`. Reconcile against provider history or the provider page. Never replay the POST automatically. A new send requires a new learner decision.

Legacy import preserves original `.algo` files, ignores imported shell commands, and leaves ambiguous historical IDs unresolved. Portable import refuses to guess a merge when event histories conflict.

Use `data_delete` in preview mode first. Session deletion redacts plugin events and removes plugin-managed handoff, snapshot, and artifact data while preserving problem source directories and provider credentials. All-learning deletion removes only `.algo/learning/`. Report retained backups or external exports that the engine cannot erase.
