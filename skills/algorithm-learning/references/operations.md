# Engine operations

Every mutation includes a stable `request_id` and the `expected_revision` returned by the last envelope. Repeating the same request and payload is safe; reusing an ID for different content fails. Read operations accept `{}` unless their schema requires a selector.

Common flow:

1. `doctor`
2. `workspace_init` or `session_resume`
3. `plan_next`, then `session_start`
4. `problem_get`, then `attempt_start`
5. `hint_record`, `case_add`, `test_run`, and `assessment_record` as work occurs
6. `session_checkpoint` during interruption or `session_close` after reflection
7. `review_due` and `progress_get`

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
algolearn call OP --workspace /path/to/practice --input request.json --json
```

Convenience commands `init`, `doctor`, and `resume` call the same registry. JSON envelopes contain `schema_version`, `request_id`, `workspace_revision`, `status`, `data`, `warnings`, `error`, and `next_actions`.

Exit codes are 0 completed, 1 operational failure, 2 invalid input or conflict, 3 failed solution, 4 unverified local result, and 5 pending. Wrong answers and unchecked cases are domain outcomes, not malformed tool calls.
