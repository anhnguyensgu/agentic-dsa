---
name: algorithm-learning
description: Run evidence-backed algorithm tutoring sessions with the local algo learning engine (`algo learn`). Use when a learner wants to study, practise, continue, review, test, or submit an algorithm problem while preserving progress across agents.
---

# Algorithm Learning

Use the `algorithm-learning` MCP server's tools when available (the Claude Code and Codex plugins provide it); otherwise invoke the JSON CLI, `algo learn`. Online judges are reached through `algo judge <provider> <command>` (providers today: `leetcode`, `kattis`). Treat the engine's workspace state as authoritative across conversations and hosts.

Resume once when entering an existing learning workspace or after context loss or a host switch. Use `doctor` for first setup or a tooling failure. Reuse the returned profile, session, attempt, problem metadata, and workspace revision during the conversation. Ordinary explanations and follow-up questions should usually require no engine calls.

For a new workspace, collect missing profile fields together and initialize once with a complete request. Use known learner preferences; ask for missing choices instead of guessing them. A direct request such as fetching today's problem can proceed before profile setup. Use `plan_next` when the learner needs a recommendation; accept an explicit problem choice directly.

Read [references/operations.md](references/operations.md) before the first CLI mutation or when an operation's schema is unclear. Discover unknown schemas once and reuse them. Do not probe fields or enum values through repeated failing calls.

Keep the learner as the author. Clarify the problem before naming an algorithm. Ask for a direct approach, cost, and a brief correctness reason, then let the learner implement. Record meaningful assistance at its actual disclosure level using the batching rules in [references/tutor-protocol.md](references/tutor-protocol.md): accumulate routine low-level hints until a milestone and persist stronger disclosures promptly. If the learner requests a full explanation or solution, provide it and record level 4 exposure; do not award independent credit afterward.

Use `attempt_start` when the learner begins an implementation or asks to register existing work. When the provider offers starters, fetch one in the requested supported language with `algo judge <provider> get --lang` (LeetCode today), then register the actual source file. The learning engine's own fresh scaffold is Odin. See the language guidance in [references/operations.md](references/operations.md). Add only cases with honest oracle provenance. Use `test_run` for execution evidence and keep unchecked cases distinct from verified passes. Record semantic judgments at assessment milestones; never present an agent claim as runner or judge evidence.

Checkpoint at an interruption, handoff, substantial change of activity, or before context loss; avoid a checkpoint for each reply. Close completed sessions with a reflection and review update. Query `review_due` when choosing review work and `progress_get` when reporting progress, using stored evidence.

For remote submission, first call `submission_prepare`. If the learner already requested this exact submission, call `submission_send` with the host authorization reference. Otherwise present the prepared provider, account, problem, language, and source hash before seeking authorization. Resume returned jobs only with `job_check`; never create a replacement submission for a pending or unknown outcome.

Read these references only when the situation requires them:

- [references/tutor-protocol.md](references/tutor-protocol.md) for diagnosis, modes, hints, feedback, and frustration.
- [references/assessment-review.md](references/assessment-review.md) before awarding independent or retained progress or completing a review.
- [references/test-design.md](references/test-design.md) for adversarial competitive-programming tests, stress campaigns, differential or property checks, and checker design.
- [references/operations.md](references/operations.md) for call selection, schemas, language support, mutation envelopes, exit codes, and CLI fallback.
- [references/recovery.md](references/recovery.md) for handoff, changed files, provider failures, uncertain submissions, imports, and deletion.
