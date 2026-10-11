# algo learn — persistent algorithm tutoring

`algo learn` is the native Odin learning engine described by
[`AGENTIC_LEARNING.md`](../AGENTIC_LEARNING.md). A host agent teaches; the
engine validates operations, preserves exact evidence, computes progress and
reviews, and makes a session resumable by another compatible agent.

## Build and verify

Odin and `curl` are required at runtime. Python is used only by the fixture,
protocol, curriculum, and packaging tests.

```sh
make build
make test
make install PREFIX="$HOME/.local"
```

The build produces `bin/algo`, plus the legacy names `bin/algolearn`,
`bin/leetcode`, and `bin/kattis` as symlinks that act as `algo learn`,
`algo judge leetcode`, and `algo judge kattis`. `make package-plugin` assembles
the current native binary and shared teaching skill under
`plugins/codex/algorithm-learning/`.

## Start a workspace

```sh
algo learn doctor --workspace ~/practice --json
algo learn init --workspace ~/practice --input profile.json --json
algo learn call plan_next --workspace ~/practice --input plan.json --json
algo learn resume --workspace ~/practice --json
```

Example `profile.json`:

```json
{
  "request_id": "init-my-practice",
  "expected_revision": 0,
  "goal": "foundations",
  "language": "odin",
  "timezone": "Asia/Ho_Chi_Minh",
  "experience": "beginner",
  "explanation_language": "English",
  "time_budget_minutes": 30
}
```

Mutations require a stable `request_id` and the `expected_revision` from the
last response. Identical retries replay safely. Reusing an ID for different
content or writing from a stale revision fails without guessing.

The machine envelope is always:

```json
{
  "schema_version": 1,
  "request_id": "...",
  "workspace_revision": 7,
  "status": "completed",
  "data": {},
  "warnings": [],
  "error": null,
  "next_actions": []
}
```

Exit codes are 0 completed, 1 operational failure, 2 invalid input or
conflict, 3 failed solution, 4 unverified local result, and 5 pending.

## Practice workflow

Use `problem_search` or `plan_next`, then `session_start` and `attempt_start`.
Fresh attempts never overwrite an existing path. `case_add` records comparator
and oracle provenance. `test_run` compiles and executes Odin with time and
output limits, a credential-filtered child environment, immutable source
snapshots, and structured verified/unverified counts.

Record delivered help immediately with `hint_record`. Scores from
`assessment_record` must reference evidence in the same session. Independent
credit requires a fresh attempt, current source matching the verified snapshot,
verified nontrivial behavior, score 3 evidence for approach, correctness, and
complexity, no agent-authored algorithm change, and hints no stronger than
level 1. Accepted and assisted work remain separate from demonstrated mastery.

`session_checkpoint` writes JSON and Markdown handoffs under
`.algo/learning/sessions/<id>/`. `session_close` applies review changes once.
The review policy is one day initially, then 3, 7, 21, and 60 days after
independent successes; help or a conceptual lapse resets to one day, while a
tool failure or interruption does not change learning progress.

## Remote jobs

`submission_prepare` captures immutable bytes, provider identity, language,
account alias, and source hash without network mutation. It refuses Odin on
LeetCode. `submission_send` requires a host authorization reference and sends
the prepared intent once by re-executing the running binary as
`algo judge <provider> submit-start`. It returns a
local durable job ID. Continue only with `job_check`.

If bytes may have been sent but no remote ID is captured, the intent becomes
`submission_outcome_unknown`; it is never replayed automatically. Reconcile it
against provider history before the learner chooses any new send.

## MCP and agent use

```sh
algo learn serve --workspace ~/practice
```

The native server implements newline-delimited MCP stdio for protocol
`2025-11-25`, including initialization, `tools/list`, `tools/call`, cancellation,
shutdown, typed input/output schemas, and equivalent text plus structured
content. Diagnostics stay on stderr. The portable teaching skill is in
`skills/algorithm-learning/`; the assembled Codex wrapper is in
`plugins/codex/algorithm-learning/`.

See [`host-guides/README.md`](../host-guides/README.md) for direct MCP and
generic shell setup.

## Storage and data control

```text
.algo/learning/
  manifest.json
  events.jsonl
  state.json
  catalog/ sessions/ attempts/ artifacts/ jobs/
  imports/ exports/ backups/
```

The event stream is authoritative; projections and handoff views are
replaceable. Existing `.algo/config.json`, `.algo/events.jsonl`, provider
credentials, caches, and problem source directories remain separate.

`import_validate` previews legacy or portable data. Legacy shell commands are
inert, ambiguous IDs remain unresolved, and no mastery is invented.
`export_create` excludes credentials, provider caches, and full statements by
default; source inclusion is explicit. Portable import restores selected source
bytes only after validating their hashes and refuses conflicting histories.

`data_delete` is preview-only unless given `execute=true` and its exact
confirmation string. Session deletion redacts plugin event content and removes
plugin-managed handoffs and snapshots while preserving solution directories.
`all_learning` removes only `.algo/learning/`.

## Offline curriculum and limits

The bundled catalogue contains 40 curated mappings across Kattis and LeetCode,
covering 10 concept groups with at least four mappings each. Selection is
deterministic, filters by time/language/offline constraints, prefers due reviews
and prerequisites, hides spoiler tags in independent assessment, and explains
capability limits.

Local execution limits reduce accidental hangs and excessive output; they are
not a security sandbox for arbitrary code. Use an operating-system sandbox when
running untrusted programs. Live provider compatibility and authenticated
submissions are optional smoke checks and are never part of the default suite.
