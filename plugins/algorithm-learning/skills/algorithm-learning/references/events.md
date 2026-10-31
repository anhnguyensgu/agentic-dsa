# Events

The tools keep no learner state. You keep it, as events in your own memory: the host's memory feature, a notes file the learner chose, or any store your host provides. The event format is `schemas/event-v2.json` in the `algo` repository, so another host, or a store built later, can read the same record.

## Shape

```json
{"schema_version": 2, "event_id": "ev_...", "timestamp": "2026-10-31T09:00:00Z",
 "actor": "agent:<host>", "type": "hint_delivered", "session_id": "...",
 "attempt_id": "...", "payload": {"level": 2, "content": "...", "concept_ids": ["graphs/bfs"]}}
```

Keep the events the tools return exactly as returned. For events you record yourself, use any unique `event_id` and the current UTC time, set `actor` to `agent:<host>`, and choose your own `session_id`. Pass that `session_id`, and the `attempt_id` from `attempt_start`, to later tool calls so their events link to yours.

## Who records what

| Kind | Recorded by | When |
| --- | --- | --- |
| `attempt_started` | `attempt_start` | Keep it; it holds the source path, source hash, and `tests_hash`. |
| `runner_observed` | `test_run` | Keep it; it holds every case result and is the only execution evidence. |
| `submission_sent` | `submit` | Keep it; its `remote_id` is how you poll the verdict. |
| `submission_outcome_unknown` | `submit` (an error result) | Keep it; it blocks any resend until reconciled. |
| `job_observed` | `job_check` | Keep the terminal one; it holds the judge verdict. |
| `session_started` | you | One objective, mode, problem, and concept IDs. |
| `session_checkpoint` | you | At interruptions, handoffs, and activity changes, with the exact next action. |
| `hint_delivered` | you | Grouped by milestone as `tutor-protocol.md` describes. |
| `evidence_recorded` | you | What the learner said or did, with `producer: learner` or `agent`. Never `tool`. |
| `assessment_recorded` | you | Rubric scores citing the `event_id`s of the evidence they rest on. |
| `session_closed` | you | Whether the session qualified as independent. |
| `review_updated` | you | The next retrieval date for a concept, as `assessment-review.md` describes. |

## Reading the record

When the learner returns or a host switches, read the kept events once and rebuild only what you need:

- the active session's objective, mode, last checkpoint, and next action;
- the strongest hint level delivered in the session, which controls eligibility;
- the latest `runner_observed` per attempt, and whether the source hash still matches the file (`attempt_start` with `register_existing`, or a new `test_run`, reports the current hash);
- unfinished submissions: a `submission_sent` with `state: queued` and no terminal `job_observed`, or any `submission_outcome_unknown`;
- reviews whose `due` date has passed;
- per concept, the strongest state the evidence supports (`assessment-review.md`).

Do not invent events, edit kept ones, or derive mastery from a summary. If the record is incomplete, say what is missing and treat the unknown parts as unknown.
