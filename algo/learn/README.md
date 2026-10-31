# algo learn — stateless algorithm practice tools

`algo learn` is a set of stateless tools a host agent calls while it teaches:
it scaffolds attempts, runs bounded local tests, and sends submissions to
online judges. It stores no learner state. Every result lists the events it
produced, and the agent keeps them in its own memory, alongside the events it
records itself for sessions, hints, assessments, and reviews. The event format
is [`../schemas/event-v2.json`](../schemas/event-v2.json), so another host, or
a store built later, can read the same record.

## Build and verify

Odin and `curl` are required at runtime. Python is used only by the fixture,
protocol, curriculum, and packaging tests.

```sh
make build
make test
make install PREFIX="$HOME/.local"
```

The build produces `bin/algo`; the tools run as `algo learn`. The agent plugin in
`../plugins/algorithm-learning/` (Claude Code, Codex, and Pi) ships no binary and
runs the installed `algo`.

## Operations

| Operation | What it does |
| --- | --- |
| `doctor` | Reports whether the workspace, Odin compiler, curriculum, and each provider are ready. |
| `curriculum_get` | Lists the 18 pattern groups in study order, or one group by `concept_id`. |
| `attempt_start` | Creates a fresh Odin scaffold, downloads an Exercism exercise, or registers an existing file. Emits `attempt_started`. |
| `test_run` | Compiles and runs an Odin source against the cases passed in, or runs its package tests. Emits `runner_observed`. |
| `submit` | Sends a source to the problem's judge once. Emits `submission_sent`, or `submission_outcome_unknown` with an error. |
| `job_check` | Polls a judge verdict by `provider` and `remote_id`. Emits `job_observed`. |

```sh
algo learn doctor --workspace ~/practice --json
algo learn call attempt_start --workspace ~/practice --input attempt.json --json
algo learn serve --workspace ~/practice        # the same operations over MCP
```

Without `--workspace`, every command uses the global algo workspace:
`$ALGO_WORKSPACE`, else `~/algo`. Paths in requests are workspace-relative.

Example `attempt.json`:

```json
{"problem_key": "kattis:twostones", "language": "odin", "session_id": "my-session"}
```

The machine envelope is always:

```json
{
  "schema_version": 2,
  "request_id": "...",
  "status": "completed",
  "data": {},
  "events": [],
  "warnings": [],
  "error": null,
  "next_actions": []
}
```

Exit codes are 0 completed, 1 operational failure, 2 invalid input, 3 failed
solution, 4 unverified local result, and 5 pending.

## Practice workflow

Any problem on a supported judge can be practised; there is no bundled problem
set. Name it by `<provider>:<slug>`, such as `leetcode:two-sum`,
`kattis:twostones`, or `exercism:leap`, and discover problems with
`algo judge <provider> list`, `show`, or `daily`. The agent decides what comes
next from its own record; `curriculum_get` describes the groups.

`attempt_start` returns an `attempt_id`, the `source_path`, its `source_hash`,
and, for a test package, a `tests_hash`. Fresh attempts never overwrite an
existing path: each goes to `problems/<provider>/<slug>/<attempt_id>/`.
Calling it twice makes two attempts; nothing deduplicates requests.

`test_run` takes the `source_path` and, for `stdin_stdout`, the cases:

```json
{"source_path": "problems/kattis/twostones/att_.../solution.odin",
 "cases": [{"name": "odd", "input": "1\n", "expected": "Alice\n", "comparator": "exact",
            "provenance": "official_example", "oracle_verified": true}]}
```

Only a case with an expected output and a verified oracle counts as passing
evidence; others are reported as unchecked, and zero cases are unverified. Runs
use time and output limits, a credential-filtered child environment, and a
temporary build directory. The `runner_observed` event carries every case
result, so nothing is left on disk.

### Exercism

Exercism exercises ship with their own tests, so they run as
`odin_test_package` attempts:

1. `curriculum_get` names the Exercism exercises mapped to each group.
2. `attempt_start` with `problem_key: exercism:<slug>` and `language: odin`
   downloads the exercise through `algo judge exercism download` into
   `problems/exercism/odin/<slug>/` and returns its solution file and
   `tests_hash`. A downloaded exercise is never downloaded again; later
   attempts use `register_existing` on the same file.
3. `test_run` with `runner_kind: odin_test_package`, the `tests_hash`, and the
   `problem_key` runs `odin test` on the exercise. Each `@(test)` procedure is
   a verified case with provenance `official_tests`. A run after the
   `*_test.odin` files changed, or without a `tests_hash`, is unverified.
4. `submit` uploads the solution through `algo judge exercism submit` and
   returns `state: uploaded`. Exercism's own results appear only on
   exercism.org, so `job_check` does not apply.

The tools must run in the global algo workspace (`$ALGO_WORKSPACE`, else
`~/algo`) after `exercism configure --token=<token>` and
`algo judge exercism setup`, because the exercism CLI decides where downloads
land.

## Remote submissions

`submit` checks the source against the `source_hash` passed in, if any, and
refuses Odin on LeetCode. It sends the file once by re-executing the running
binary as `algo judge <provider> submit-start` (`submit` for Exercism) and
returns the judge's `remote_id`. The caller keeps it and polls with
`job_check`; the tools keep no job list, so a lost `remote_id` must be
recovered from the provider's submission history, never by submitting again.

If bytes may have been sent but no remote ID was captured, `submit` fails with
`submission_outcome_unknown` and still returns that event, so the caller can
block a blind resend.

## MCP and agent use

```sh
algo learn serve --workspace ~/practice
```

The native server implements newline-delimited MCP stdio for protocol
`2025-11-25`, including initialization, `tools/list`, `tools/call`, cancellation,
shutdown, typed input/output schemas, and equivalent text plus structured
content. Diagnostics stay on stderr. The portable teaching skill is in
`../plugins/algorithm-learning/skills/algorithm-learning/`; its
`references/events.md` explains which events the agent records itself.

See [`../plugins/README.md`](../../plugins/README.md) to set up Claude Code, Codex,
Pi, DeepTutor, or any other agent through MCP or the JSON CLI.

## Earlier versions

Engine 0.4 and earlier stored events, state, handoffs, and artifacts under
`.algo/learning/` and offered sessions, hints, assessments, reviews, planning,
and import/export as operations. Those now belong to the agent. The tools
neither read nor change an existing `.algo/learning/`; the skill tells agents
how to read it as legacy history.

## Curriculum and limits

`curriculum/concepts.json` holds 18 pattern groups in study order (arrays and
hashing, two pointers, stack, binary search, sliding window, linked list,
trees, tries, heap, backtracking, intervals, greedy, graphs, advanced graphs,
1-D and 2-D dynamic programming, bit manipulation, math and geometry), each
with prerequisites, learning outcomes, and the LeetCode topic tags that
practise it. Thirteen of them also map concrete Exercism exercises in
`problems.exercism`; tries, heap, intervals, greedy, and advanced graphs have
no fitting exercise.

Agents may also name free-form sub-patterns as `<group>/<pattern>`, such as
`graphs/topological-sort` or `dp-2d/knapsack`, and roll them up under their
group; `curriculum_get` accepts either form.

Local execution limits reduce accidental hangs and excessive output; they are
not a security sandbox for arbitrary code. Use an operating-system sandbox when
running untrusted programs. Live provider compatibility and authenticated
submissions are optional smoke checks and are never part of the default suite.
