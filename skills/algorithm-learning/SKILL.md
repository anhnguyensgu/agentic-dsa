---
name: algorithm-learning
description: Run evidence-backed algorithm tutoring sessions with the local algolearn engine. Use when a learner wants to study, practise, continue, review, test, or submit an algorithm problem while preserving progress across agents.
---

# Algorithm Learning

Use the `algolearn` MCP tools when available; otherwise invoke the JSON CLI. Treat its workspace state as authoritative across conversations and hosts.

Start by calling `doctor` and `session_resume`. If the workspace is new, initialize it from the learner's goal, language, experience, timezone, explanation language, and usual time budget. State one learning objective and select from `plan_next`, while accepting an explicit learner choice.

Keep the learner as the author. Clarify the problem before naming an algorithm. Ask for a direct approach, cost, and a brief correctness reason, then let the learner implement. Record every meaningful hint at its actual disclosure level when delivered. If the learner requests a full explanation or solution, provide it and record level 4 exposure; do not award independent credit afterward.

Use `attempt_start` for a fresh or explicitly registered attempt. Add only cases with honest oracle provenance. Use `test_run` for execution evidence and keep unchecked cases distinct from verified passes. Record semantic judgments with `assessment_record`; never present an agent claim as runner or judge evidence.

Checkpoint useful work before context loss and close completed sessions with a reflection and review update. Run `review_due` and `progress_get` from stored evidence rather than inferring progress from chat history or accepted counts.

For remote submission, first call `submission_prepare`. If the learner already requested this exact submission, call `submission_send` with the host authorization reference. Otherwise present the prepared provider, account, problem, language, and source hash before seeking authorization. Resume returned jobs only with `job_check`; never create a replacement submission for a pending or unknown outcome.

Read these references only when the situation requires them:

- [references/tutor-protocol.md](references/tutor-protocol.md) for diagnosis, modes, hints, feedback, and frustration.
- [references/assessment-review.md](references/assessment-review.md) before awarding independent or retained progress or completing a review.
- [references/test-design.md](references/test-design.md) for adversarial competitive-programming tests, stress campaigns, differential or property checks, and checker design.
- [references/operations.md](references/operations.md) for operation order, mutation envelopes, exit codes, and CLI fallback.
- [references/recovery.md](references/recovery.md) for handoff, changed files, provider failures, uncertain submissions, imports, and deletion.
