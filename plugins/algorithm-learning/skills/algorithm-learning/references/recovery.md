# Recovery and handoff

After context loss or a host switch, read your kept events (`events.md`) instead of restarting onboarding. Continue the last checkpoint's next action and unanswered question. Before describing earlier test evidence as current, check that the source still matches the hash in the latest `runner_observed`; if it changed, run the tests again.

A handoff to another host works only if that host can read the same record. When the learner switches hosts, offer to export the kept events as JSON lines they can give the next host.

For provider timeouts, rate limits, expired sessions, or response changes, keep the attempt and any submission events. Treat local tooling failure as no learning outcome. Use the provider's existing login flow without exposing credentials to the tutor: the learner runs `algo judge <provider> auth`, and `algo judge <provider> status` verifies the saved session.

If `submit` returns `submission_outcome_unknown`, the request may have reached the judge without a remote ID. Keep that event and treat the submission as unresolved: reconcile against the provider's submission history or page, and never resend automatically. A new submission requires a new learner decision. The same applies when you lose a `remote_id` you never recorded.

Legacy data: engine 0.4 and earlier kept events in `.algo/learning/events.jsonl` in the workspace. If you find that file, read it as prior history: its sessions, hints, runs, and assessments keep their meaning, but carry them into your record only as `legacy` evidence and infer no mastery the events do not show. Leave the file and older `.algo/config.json` data untouched.

To forget learner data, delete the kept events from your own memory. Solution files under `problems/` belong to the learner and stay unless they ask.
