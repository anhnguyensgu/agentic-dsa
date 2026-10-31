# Algorithm Learning verification report

Date: 2026-09-20; stateless tools (engine 0.5.0) re-verified 2026-10-31 on
macOS arm64 with Odin `dev-2026-10:84bc3fc21`.

Environment: macOS arm64, Odin `dev-2026-07:819fdc7a8`, Pi 0.85.1. The
default suite uses loopback fixtures and synthetic credentials and creates no
real submissions.

## Commands and results

```text
make test
  odin check -vet -strict-style passed for every package
  4 shared judge core unit tests passed
  19 LeetCode unit tests passed
  7 practice-tool unit tests passed (memory tracking enabled)
  68 LeetCode fixture checks passed
  39 Kattis fixture/bounded-runner checks passed
  21 Exercism pass-through checks passed (stub exercism CLI)
  22 stateless practice end-to-end checks passed
  20 Exercism practice-tool checks passed (stub exercism CLI, fixture catalogue)
  11 reviewed teaching/recovery scenario contracts passed
  9 native MCP protocol checks passed
  single-plugin packaging (Claude Code, Codex, Pi) and install/upgrade/uninstall checks passed

python3 tests/live_smoke.py
  PASS: LeetCode public discovery, lookup, cache, daily/random, languages,
  and scaffold on 2026-09-20

./bin/algo judge kattis list --page 0 --json
./bin/algo judge kattis show twostones --json
  PASS: Kattis public catalogue and problem normalization on 2026-09-20

PI_OFFLINE=1 pi --skill skills/algorithm-learning --list-models
  PASS: Pi 0.85.1 accepted the shared skill path without a model call

claude plugin validate --strict ../plugins/algorithm-learning (and ../plugins/)
claude plugin marketplace add ./plugins && claude plugin install algorithm-learning@agentic-dsa
codex plugin marketplace add ./plugins && codex plugin add algorithm-learning@agentic-dsa
echo '{"type":"get_commands"}' | pi --mode rpc --no-session -e ../plugins/algorithm-learning
  PASS on 2026-10-20 with isolated CLAUDE_CONFIG_DIR and CODEX_HOME: Claude Code
  2.1.304 and Codex 0.161.0 installed the one plugin and started its MCP server;
  Pi 1.0.2 loaded skill:algorithm-learning from the same folder
```

DeepTutor 1.7.0 (PyPI, Python 3.13.18), 2026-10-31
  PASS: its MCP probe listed the six tools (curriculum_get was removed
  later that day); its MCPConnectionManager and tool
  adapters ran doctor, curriculum_get, attempt_start, test_run (2 verified
  cases passed), and a refused LeetCode Odin submit against a scratch
  workspace, which gained no .algo/; `deeptutor skill list` showed the skill;
  `deeptutor run chat` on gpt-6-luna (openai_codex) read the skill, loaded
  the tools with load_tools, and answered from doctor and curriculum_get.
  CLI Apps: algo installed by hand under data/cli-apps (state.json row and
  bin entry) was authorized, but build_app_tools built no chat tool because
  the bundled CLI-Anything catalog does not list it. Without a sandbox the
  runner refused ("no sandbox backend available"); with
  DEEPTUTOR_SANDBOX_ALLOW_SUBPROCESS=1 its runner ran `learn doctor` (ready)
  and `learn call attempt_start` (attempt_started event), and a directly built
  cli_algo tool returned the doctor envelope. Then, with an algo entry added
  to the catalog in memory for one process (no DeepTutor file edited),
  DeepTutor's own installer pip-installed a one-file package whose `algo`
  command execs the real binary, and `deeptutor run chat` loaded cli_algo
  with load_tools and ran `algo learn doctor` through it in the subprocess
  sandbox, answering engine_version 0.5.0 and ready. Both installs were
  removed again (the second with DeepTutor's uninstaller).
  See ../plugins/README.md#deeptutor.

Counts above are the expected final counts after the complete suite. The report
must be updated if later edits change them.

## Acceptance matrix

| ID | Status | Evidence |
| --- | --- | --- |
| A01 | Moved to the agent (0.5.0) | The tools store nothing. `tests/learning_integration.py` scaffolds, tests, and refuses submissions, and checks every emitted event against `schemas/event-v2.json`; planning, sessions, and schedules are kept by the agent per the skill's `events.md`. |
| A02 | Pass | LeetCode and Kattis fixture suites exercise structured discovery, problem data, safe scaffolds, local runners, and job contracts; both feed the same engine through `<provider>:<slug>` problem keys. |
| A03 | Pass | `tests/mcp_protocol.py` compares MCP `doctor` with the CLI result, checks equivalent structured/text envelopes, tool descriptions and schemas, and emitted events. |
| A04 | Moved to the agent (0.5.0) | Handoff is the agent's kept event record; changed-source hashes are still enforced by `submit`'s `source_hash` and reported by every run. |
| A05 | Pass | `../plugins/README.md` documents shell and text-only behavior; the CLI and native MCP process are exercised directly. |
| A06 | Pass | LeetCode and Kattis collision fixtures preserve existing source bytes; engine fresh attempts reject existing or symlink-escaped destinations. |
| A07 | Retired (0.5.0) | The tools neither read nor write `.algo/`; the skill tells agents to read old logs as legacy history and infer no mastery. End-to-end tests check that no `.algo/` is created. |
| A08 | Pass | Unit and reviewed teaching scenarios cover light/decisive help, cumulative disclosure, copied or agent-authored code, direct solutions, and translation-level exposure. |
| A09 | Moved to the agent (0.5.0) | The rules live in the skill's `assessment-review.md`; the tools supply the evidence they rest on (fresh attempts, verified runs, source hashes, judge verdicts). |
| A10 | Moved to the agent (0.5.0) | Review scheduling is recorded by the agent as `review_updated` events, following the intervals in `assessment-review.md`. |
| A11 | Pass | Empty, unchecked, wrong, and verified cases have distinct outcomes; provider runners emit structured counts and never call zero/unchecked cases all passed. |
| A12 | Pass | LeetCode Odin preparation is refused before network activity; local Odin and supported remote-language capabilities are explicit. |
| A13 | Pass, revised (0.5.0) | `submit` sends once, refuses stale sources and Odin on LeetCode before any network activity, and reports an ambiguous send as `submission_outcome_unknown` with its event; the agent keeps remote IDs and blocks resends. LeetCode start/check is fixture-tested. |
| A14 | Pass, revised (0.5.0) | `runner_observed` events carry the source hash and every case result; no artifacts or snapshots are written. |
| A15 | Retired (0.5.0) | There is no event log, projection, or lock to protect. |
| A16 | Pass | Synthetic secrets are absent from child runners and provider diagnostics are bounded; there are no exports. |
| A17 | Pass (macOS; Linux x86_64 on 2026-10-20) | Hanging and excessive-output programs are stopped with usable diagnostics on both systems; see the Linux run below. |
| A18 | Pass | Eleven reviewed scenario contracts cover diagnosis, repeated help, direct answers, copied work, misleading tests, overwrite pressure, provider changes, unknown submissions, legacy history, strong-hint handoff, and frustration; each names the tool operations and event kinds it relies on. |
| A19 | Moved to the agent (2026-10-31) | The bundled problem set was removed on 2026-10-20, and the curriculum on 2026-10-31: learning paths belong to the agent, and the skill's `references/curriculum.md` keeps the 18 pattern groups with their LeetCode tags and Exercism exercises as a default path. Problem keys are validated by provider and slug shape (unit and end-to-end tests). |
| A20 | Pass (macOS); Linux build and temp-prefix install pass | `tests/packaging.py` checks that the one plugin holds the only skill copy and no binary, validates the Claude Code, Codex, and Pi manifests and both marketplaces, exercises the launcher's binary fallbacks, and checks temp-prefix install, upgrade, and uninstall with learner data preserved. Real installs into isolated Claude Code 2.1.304 and Codex 0.161.0 configs and Pi 1.0.2 loading were checked on 2026-10-20. The plugin ships no binary; the launcher uses `ALGOLEARN_BIN`, `algo` on `PATH`, or `~/.local/bin/algo`. |
| A21 | Pass | Existing LeetCode unit/integration suites pass; Kattis now has a fixture-controlled regression suite. |
| A22 | Pass with authenticated checks not run | Dated public reads pass for both providers. Authenticated reads, remote runs, and real submissions were not run because they require explicit account authorization. |

## Linux run, 2026-10-20

Environment: Linux x86_64, Odin `dev-2026-07:819fdc7` built from source against
LLVM 20. `make test` passed with the counts listed above, after the bundled
problem set was removed. Live LeetCode reads were not run because the host
network blocked leetcode.com, so the LeetCode topic tags (now in the skill's
`references/curriculum.md`) are not live-verified.

## Remaining release evidence

Authenticated provider checks remain opt-in. A learner study with
pre/post and delayed transfer tasks is also still required before making any
claim that the product improves learning; technical acceptance does not prove
educational effectiveness.
