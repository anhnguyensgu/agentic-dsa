---
name: algorithm-learning
description: Run evidence-backed algorithm tutoring sessions with the stateless `algo learn` practice tools. Use when a learner wants to study, practise, continue, review, test, or submit an algorithm problem.
---

# Algorithm Learning

Use the `algorithm-learning` MCP server's tools when available (the Claude Code and Codex plugins provide it, and any MCP host such as DeepTutor can run `algo learn serve`); otherwise invoke the JSON CLI, `algo learn call`. Online judges are reached through `algo judge <provider> <command>` (providers today: `leetcode`, `kattis`, `exercism`).

The tools store nothing. Every result carries an `events` array; keep those events in your own memory, together with the events you record yourself for sessions, hints, assessments, and reviews. Your memory is the learner's record: read it when the learner returns, and pass the tools whatever they need from it, such as a source path, a `tests_hash`, or a judge `remote_id`. Read [references/events.md](references/events.md) before recording the first event.

Use `doctor` for first setup or a tooling failure. Ordinary explanations and follow-up questions need no tool calls. Collect missing learner preferences together and keep them in memory. Decide what to practise next yourself from the learner's record; the tools carry no curriculum. [references/curriculum.md](references/curriculum.md) is a default study path with LeetCode tags and Exercism exercises per pattern group; follow it, adapt it, or use a more specific learning-path skill. Accept an explicit problem choice directly.

Read [references/operations.md](references/operations.md) before the first CLI call or when a tool's schema is unclear. Do not probe fields or enum values through repeated failing calls.

Keep the learner as the author. Clarify the problem before naming an algorithm. Ask for a direct approach, cost, and a brief correctness reason, then let the learner implement. Record meaningful assistance at its actual disclosure level using the batching rules in [references/tutor-protocol.md](references/tutor-protocol.md). If the learner requests a full explanation or solution, provide it and record level 4 exposure; do not award independent credit afterward.

Use `attempt_start` when the learner begins an implementation or asks to register existing work. When the provider offers starters, fetch one in the requested supported language with `algo judge <provider> get --lang` (LeetCode today), then register the actual source file. Pass only cases with honest oracle provenance to `test_run`, and keep unchecked cases distinct from verified passes. Never present your own claim as runner or judge evidence.

Record a checkpoint at an interruption, handoff, substantial change of activity, or before context loss; avoid one for each reply. Close completed sessions with a reflection and a review entry.

For remote submission, call `submit` only after the learner asked for this exact submission, with their request as `authorization_reference` and the `source_hash` of the run you are relying on. Keep the returned `remote_id` and poll with `job_check`. Never submit again for a pending or `submission_outcome_unknown` result.

Read these references only when the situation requires them:

- [references/events.md](references/events.md) for the events to keep and how to reconstruct the learner's state from them.
- [references/curriculum.md](references/curriculum.md) when choosing the next pattern group or problem.
- [references/tutor-protocol.md](references/tutor-protocol.md) for diagnosis, modes, hints, feedback, and frustration.
- [references/assessment-review.md](references/assessment-review.md) before awarding independent or retained progress or completing a review.
- [references/test-design.md](references/test-design.md) for adversarial competitive-programming tests, stress campaigns, differential or property checks, and checker design.
- [references/operations.md](references/operations.md) for tool selection, schemas, language support, exit codes, and CLI fallback.
- [references/recovery.md](references/recovery.md) for handoff, changed files, provider failures, uncertain submissions, and legacy data.
