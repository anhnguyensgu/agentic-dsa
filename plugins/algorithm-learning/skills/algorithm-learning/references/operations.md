# Tool operations

Call a tool when the learner needs new external information, execution, or a submission. The tools are stateless: they read nothing from earlier calls, so pass what they need from your kept events. A learning conversation is not a checklist to rerun on each message.

## Choose calls by need

| Situation | Calls |
| --- | --- |
| First setup or tooling failure | `doctor`. |
| Learner returns, or a host switch | No tool call; read your kept events (`events.md`). |
| Learner asks for today's problem | Fetch the provider daily problem once (`algo judge leetcode daily`) and reuse its statement. |
| Learner names or links a problem | Practise it directly; any problem on a supported judge works. Fetch it with `algo judge <provider> show`. |
| Learner asks what to practise next | Decide from the record: due reviews first, then the next curriculum group. `curriculum_get` gives the groups in study order with `leetcode_tags` and mapped Exercism exercises; pick an unattempted LeetCode problem with `algo judge leetcode random --tag <tag>` or `list`. Do not show tags to the learner in independent work. |
| Learner begins implementation or registers work | For a requested provider starter, `algo judge <provider> get --lang` into a fresh directory; then `attempt_start` once with the correct language and source path. Keep the returned event. |
| Ordinary discussion of the same problem | No calls; collect routine hints as described in `tutor-protocol.md`. |
| Testing | Record pending hints, then `test_run` with the source path and cases, or with `tests_hash` for an Exercism package. Keep the `runner_observed` event. |
| Submission the learner asked for | `submit`, then `job_check` with the returned `remote_id` until terminal. |

## Schemas and requests

Use exposed MCP input schemas. In CLI-only hosts such as Pi, discover unknown schemas with the MCP server once, then retain the relevant fields in context. This read-only exchange exits at stdin EOF:

```sh
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"skill-schema","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  | algo learn serve --workspace /path/to/practice
```

After `invalid_input`, inspect the schema and error before one corrected retry. If it still fails, report the specific tooling obstacle and continue any tutoring that does not depend on it. Do not try a series of guessed payloads.

Quick reference for engine 0.5.0; live schemas and validation take precedence:

| Operation | Inputs that commonly cause mistakes |
| --- | --- |
| `curriculum_get` | Optional `concept_id`: a group, or `<group>/<pattern>`, which returns its group. |
| Concept IDs | Use the specific pattern the learner actually exercised, written `<group>/<pattern>` under one of the 18 curriculum groups (`arrays-hashing`, `two-pointers`, `stack`, `binary-search`, `sliding-window`, `linked-list`, `trees`, `tries`, `heap`, `backtracking`, `intervals`, `greedy`, `graphs`, `advanced-graphs`, `dp-1d`, `dp-2d`, `bit-manipulation`, `math-geometry`), such as `graphs/topological-sort`. Reuse a sub-pattern ID already in your record instead of inventing a synonym. |
| `attempt_start` | Required: `problem_key`, `language`. `problem_key` is `<provider>:<slug>` for `leetcode`, `kattis`, or `exercism`, using the LeetCode title slug, Kattis problem ID, or Exercism exercise slug (lowercase), such as `leetcode:two-sum` or `exercism:leap`. `action`: `fresh` (default) or `register_existing`, which needs an existing workspace-relative `source_path`. `runner_kind`: `stdin_stdout`, `odin_test_package`, or `provider_workspace`; Exercism defaults to `odin_test_package`. For Exercism, `language` is the track (`odin`) and `fresh` downloads the exercise; once downloaded it fails with `destination_exists`, so later attempts use `register_existing` with the solution file under `problems/exercism/<track>/<slug>/`. Optional `session_id` and `previous_attempt_id` are copied into the event. |
| `test_run` | Required: `source_path` (an Odin file). `stdin_stdout` takes `cases`: each needs `input`, `comparator` (`exact`, `trimmed`, `tokens`), and `provenance`; `expected` and `oracle_verified: true` make it verifiable. `odin_test_package` runs the package's `@(test)` procedures and needs the `tests_hash` from `attempt_start`; pass `problem_key` so Exercism tests are marked `official_tests`. Without `tests_hash`, or after the tests changed, the run is unverified. |
| `submit` | Required: `problem_key`, `language` (the provider's language name), `source_path`, `authorization_reference`. Pass `source_hash` from the run you rely on; a changed file fails with `stale_source`. LeetCode does not judge Odin. |
| `job_check` | Required: `provider`, `remote_id` from `submit`. Optional `wait_seconds` (1–30). Exercism has no verdict to check. |

Every call accepts an optional `request_id`, echoed in the envelope. Repeating a call repeats its effect: a second `attempt_start` creates a second attempt, and a second `submit` creates a second submission. Write learner text and JSON through a structured tool argument, a file, or safely supplied stdin rather than interpolating it into shell code.

## Requested language

The guaranteed local runner and the `fresh` scaffold are Odin. Setting `language: typescript` with `runner_kind: provider_workspace` does not change the scaffold's extension.

When the provider offers starters in the requested language, fetch one rather than creating an empty file or using the Odin scaffold. Today only LeetCode offers multi-language starters; `algo judge kattis get` scaffolds Odin only. For LeetCode, reuse `codeSnippets` from an already fetched problem to check language support, and call `algo judge leetcode languages <problem> --json` only when that information is missing. The language name is the provider's own: LeetCode's `langSlug` (such as `typescript` or `python3`), or the judge's language name for Kattis.

When the learner wants a starter workspace, use a fresh destination inside the practice workspace:

```sh
algo judge leetcode get valid-parentheses --lang typescript \
  --workspace /path/to/practice \
  --dir /path/to/practice/problems/leetcode/valid-parentheses/typescript-attempt-1 --json
```

Register the generated source, or the learner's existing file, with `action: register_existing`, its workspace-relative `source_path`, the requested `language`, and `runner_kind: provider_workspace`. This registration does not provide a verified local runner for that language and is not a fresh attempt. Do not award fresh-attempt credit or claim local execution support from it.

## Remote operations

1. `submit` once, after the learner's explicit request.
2. `job_check` with the returned `provider` and `remote_id` until `state: terminal`.

Exercism has no verdict to wait for: `submit` uploads the exercise's solution file through the exercism CLI and returns `state: uploaded`. Its tests run on exercism.org, so assess from the local `test_run` evidence. The exercism CLI must be set up once with `exercism configure --token=<token>` and `algo judge exercism setup`; a missing token is reported as `auth_required`.

## CLI fallback

```sh
algo learn call OP --workspace /path/to/practice --input request.json --json
```

`algo learn doctor` calls the same registry. JSON envelopes contain `schema_version`, `request_id`, `status`, `data`, `events`, `warnings`, `error`, and `next_actions`; even an error can carry an event, such as `submission_outcome_unknown`.

Exit codes for `algo learn` are 0 completed, 1 operational failure, 2 invalid input, 3 failed solution, 4 unverified local result, and 5 pending. `algo judge` provider commands use 0 success, 1 operational error, 2 usage, 3 failed solution, and 4 local cases without expected output. Wrong answers and unchecked cases are domain outcomes, not malformed tool calls.
