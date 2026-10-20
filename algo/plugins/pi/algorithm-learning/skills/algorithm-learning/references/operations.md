# Engine operations

Call the engine when the learner needs stored state, new external information, execution, or a meaningful durable change. Reuse information already returned. A learning conversation is not a checklist to rerun on each message.

## Choose calls by need

| Situation | Calls |
| --- | --- |
| Enter an existing learning workspace or recover lost context | `session_resume` once; its handoff includes profile, latest attempt, hints, results, and pending jobs. |
| First setup or tooling failure | `doctor`; initialize only after required profile fields are known. |
| Learner asks for today's problem | Fetch the provider daily problem once (`algo judge leetcode daily`) and reuse its statement. |
| Learner names or links a problem | Practise it directly; any problem on a supported judge can be tracked. Fetch it with `algo judge <provider> show`. |
| Learner asks what to practise next | `plan_next`, or `review_due` for review work. `plan_next` names a concept and LeetCode topic tags, not a problem: pick an unattempted one with `algo judge leetcode random --tag <tag>` or `list`, avoiding `attempted_problem_keys`. |
| Start a learning session | `session_start` once with one objective and the accepted problem. |
| Learner begins implementation or registers work | For a requested provider starter, `algo judge <provider> get --lang` into a fresh directory; then `attempt_start` once with the correct language and source path. Reuse an existing learner file when supplied. |
| Ordinary discussion of the same problem | Usually no calls; collect routine hints as described in `tutor-protocol.md`. |
| Testing or assessment | Flush pending assistance, then record the actual cases, execution, or assessment needed. |
| Interruption, handoff, substantial activity change, or context loss | Flush pending assistance, then `session_checkpoint`. |
| Finished learning session or requested progress report | `session_close` after reflection; `progress_get` when reporting progress. |

Keep `workspace_revision`, active IDs, schemas, and the strongest recorded assistance level in the current context. Perform dependent mutations sequentially, using the revision returned by the preceding call. Related necessary calls may share one host tool invocation; never parallelize mutations against the same revision. Refresh state after a revision conflict or a known change by another host.

## Schemas and requests

Use exposed MCP input schemas. In CLI-only hosts such as Pi, discover unknown schemas with the native MCP server once, then retain the relevant fields and required values in context. This read-only exchange exits at stdin EOF:

```sh
printf '%s\n' \
  '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25","capabilities":{},"clientInfo":{"name":"skill-schema","version":"1"}}}' \
  '{"jsonrpc":"2.0","method":"notifications/initialized"}' \
  '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}' \
  | algo learn serve --workspace /path/to/practice
```

Do not read the executable as text or write a discovery program on every turn. The schemas list fields and required inputs; string enums may need the quick reference below or the matching handler source. After `invalid_input`, inspect the schema and error before one corrected retry. If it still fails, report the specific tooling obstacle and continue any tutoring that does not depend on it. Do not try a series of guessed payloads.

Quick reference for engine 0.3.0; live schemas and validation take precedence:

| Operation | Inputs that commonly cause mistakes |
| --- | --- |
| `workspace_init` | Required: `goal`, `language`, `timezone`, `experience`, `time_budget_minutes` (integer 5–480). Optional: `explanation_language`. Collect missing preferences together before calling. |
| `plan_next` | Optional: `topic` (a concept ID), `mode`, `language`, `time_budget_minutes`. Returns at most one due review and one concept with `leetcode_tags`; when `hide_tags_from_learner` is true, do not show those tags. |
| `session_start` | Required: `objective`, `mode`. Modes: `guided`, `independent`, `assessment`, `review`, `worked_example`. Accepts `problem_key` and `concept_ids`. |
| Concept IDs | Use the specific pattern the learner actually exercised, written `<group>/<pattern>` under one of the 18 curriculum groups (`arrays-hashing`, `two-pointers`, `stack`, `binary-search`, `sliding-window`, `linked-list`, `trees`, `tries`, `heap`, `backtracking`, `intervals`, `greedy`, `graphs`, `advanced-graphs`, `dp-1d`, `dp-2d`, `bit-manipulation`, `math-geometry`), such as `graphs/topological-sort` or `dp-2d/knapsack`. Reuse an existing sub-pattern ID from `progress_get` instead of inventing a synonym. Use the bare group only when no narrower pattern applies. Apply the same IDs to `session_start`, `hint_record`, and `assessment_record`. |
| `session_checkpoint` | Required: `session_id`, `activity`, `summary`, `next_action`. Activities: `understanding`, `planning`, `implementing`, `testing`, `reflecting`, `reviewing`. |
| `hint_record` | Required: `session_id`, integer `level` (0–4). Optional: `attempt_id`, `content`, `concept_ids`. |
| `attempt_start` | Required: `session_id`, `problem_key`, `language`. `problem_key` is `<provider>:<slug>` for any problem on `leetcode` or `kattis`, using the LeetCode title slug or Kattis problem ID (lowercase), such as `leetcode:two-sum`. `action`: `fresh` or `register_existing`. `runner_kind`: `stdin_stdout`, `odin_test_package`, or `provider_workspace`. `register_existing` needs an existing workspace-relative `source_path`. |

Every mutation also includes a stable `request_id` and the `expected_revision` returned by the last envelope. Repeating the same request and payload is safe; reusing an ID for different content fails. Read operations accept `{}` unless their schema requires a selector. Write learner text and JSON through a structured tool argument, a file, or safely supplied stdin rather than interpolating it into shell code.

## Requested language

The current guaranteed local runner and `action: fresh` scaffold are Odin. Setting `language: typescript` with `runner_kind: provider_workspace` does not change the fresh scaffold's extension.

When the provider offers starters in the requested language, fetch one rather than creating an empty file or using the engine's Odin scaffold. Today only LeetCode offers multi-language starters; `algo judge kattis get` scaffolds Odin only. For LeetCode, reuse `codeSnippets` from an already fetched problem to check language support, and call `algo judge leetcode languages <problem> --json` only when that information is missing. The language selector is the provider's own name for the language: LeetCode's `langSlug` (such as `typescript` or `python3`), or the judge's language name for Kattis submissions.

When the learner wants a starter workspace, use a fresh destination inside the practice workspace:

```sh
algo judge leetcode get valid-parentheses --lang typescript \
  --workspace /path/to/practice \
  --dir /path/to/practice/problems/leetcode/valid-parentheses/typescript-attempt-1 --json
```

`get` writes the provider starter as `solution.ts` in this example, along with the statement, metadata, and example cases. It refuses an existing destination. Reuse the fetched problem and examples.

Register the generated source, or the learner's existing file, with `action: register_existing`, its workspace-relative `source_path`, the requested `language`, and `runner_kind: provider_workspace`. Check the returned source path before directing the learner to it. Preserve earlier work and let the learner write the solution. For a provider without starter support, an empty file at a fresh destination remains an option when file creation is requested.

This registration does not provide a verified local runner for that language and is not marked as a fresh attempt by the engine. Do not award fresh-attempt credit or claim local execution support from it.

## Remote and data operations

Remote flow:

1. `submission_prepare`
2. `submission_send` once with an authorization reference
3. `job_check` on the returned local job ID until terminal

Data flow:

- `export_create` creates a private profile/history or handoff export and lists excluded content.
- `import_validate` previews legacy or portable data without mutation.
- `import_apply` checks the validated source hash before applying.
- `data_delete` returns a preview unless `execute=true` and the exact confirmation string is supplied.

CLI fallback:

```sh
algo learn call OP --workspace /path/to/practice --input request.json --json
```

Convenience commands `algo learn init`, `doctor`, and `resume` call the same registry. Engine exit codes below apply to `algo learn`; `algo judge` provider commands use 0 success, 1 operational error, 2 usage, 3 failed solution, and 4 local cases without expected output. JSON envelopes contain `schema_version`, `request_id`, `workspace_revision`, `status`, `data`, `warnings`, `error`, and `next_actions`.

Exit codes are 0 completed, 1 operational failure, 2 invalid input or conflict, 3 failed solution, 4 unverified local result, and 5 pending. Wrong answers and unchecked cases are domain outcomes, not malformed tool calls.
