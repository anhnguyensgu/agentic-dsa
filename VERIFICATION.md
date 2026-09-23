# Algorithm Learning verification report

Date: 2026-09-20

Environment: macOS arm64, Odin `dev-2026-07:819fdc7a8`, Pi 0.85.1. The
default suite uses loopback fixtures and synthetic credentials and creates no
real submissions.

## Commands and results

```text
make test
  19 LeetCode unit tests passed
  13 Algorithm Learning unit tests passed
  67 LeetCode fixture checks passed
  13 Kattis fixture/bounded-runner checks passed
  28 end-to-end learning checks passed
  10 reviewed teaching/recovery scenario contracts passed
  8 native MCP protocol checks passed
  40 mappings / 10 concepts validated, minimum mapping coverage 4
  native plugin packaging and install/upgrade/uninstall checks passed

python3 tests/live_smoke.py
  PASS: LeetCode public discovery, lookup, cache, daily/random, languages,
  and scaffold on 2026-09-20

./bin/kattis list 0 --json
./bin/kattis show twostones --json
  PASS: Kattis public catalogue and problem normalization on 2026-09-20

PI_OFFLINE=1 pi --skill skills/algorithm-learning --list-models
  PASS: Pi 0.85.1 accepted the shared skill path without a model call
```

Counts above are the expected final counts after the complete suite. The report
must be updated if later edits change them.

## Acceptance matrix

| ID | Status | Evidence |
| --- | --- | --- |
| A01 | Pass | `tests/learning_integration.py` initializes, plans, practises, tests, assesses, closes, schedules, exports, and resumes state; frozen-clock unit tests verify due dates. |
| A02 | Pass | LeetCode and Kattis fixture suites exercise structured discovery, problem data, safe scaffolds, local runners, and job contracts; both use the shared normalized engine catalogue. |
| A03 | Pass | `tests/mcp_protocol.py` compares MCP `state_get` with CLI state and checks equivalent structured/text envelopes. |
| A04 | Pass | Checkpoint handoffs, changed-source hashes, portable export/import, and restored source bytes are exercised end to end. |
| A05 | Pass | `host-guides/README.md` documents shell and text-only behavior; the CLI and native MCP process are exercised directly. |
| A06 | Pass | LeetCode and Kattis collision fixtures preserve existing source bytes; engine fresh attempts reject existing or symlink-escaped destinations. |
| A07 | Pass | Legacy hashes remain unchanged, imported shell commands stay inert, ambiguous events remain unresolved, and identical reimport is idempotent. |
| A08 | Pass | Unit and reviewed teaching scenarios cover light/decisive help, cumulative disclosure, copied or agent-authored code, direct solutions, and translation-level exposure. |
| A09 | Pass | Independent promotion requires fresh authorship, three evidence-linked rubric dimensions, current verified source, and bounded assistance; acceptance is a separate judge view. |
| A10 | Pass | Frozen-clock tests cover initial, 3/7/21/60-day advancement, help/lapse reset, skip/tool neutrality, overdue filtering, and snooze/resume. |
| A11 | Pass | Empty, unchecked, wrong, and verified cases have distinct outcomes; provider runners emit structured counts and never call zero/unchecked cases all passed. |
| A12 | Pass | LeetCode Odin preparation is refused before network activity; local Odin and supported remote-language capabilities are explicit. |
| A13 | Pass | Immutable prepare/send/check boundaries, local request deduplication, captured remote IDs, pending continuation, stale source, and unknown-outcome no-replay behavior are implemented; LeetCode start/check is fixture-tested. |
| A14 | Pass | Run artifacts include source hashes and immutable source snapshots; edits invalidate current eligibility and prepared submissions. |
| A15 | Pass | Tests cover atomic projection writes, truncated-tail preservation, middle corruption, duplicate requests, stale revisions, and concurrent client locking. |
| A16 | Pass | Exports exclude credentials/caches/statements, synthetic secrets are absent from child runners, and provider diagnostics are bounded. |
| A17 | macOS pass; Linux pending | Hanging and excessive-output programs are stopped on macOS. Linux source is portable, but no live Linux runner was available in this workspace. |
| A18 | Pass | Ten reviewed scenario contracts cover diagnosis, repeated help, direct answers, copied work, misleading tests, overwrite pressure, provider changes, ambiguous import, strong-hint handoff, and frustration. |
| A19 | Pass | `tests/validate_curriculum.py` validates graph edges, 40 mappings, provider identities, capabilities, URLs, origins, and at least four mappings per concept. |
| A20 | macOS/Pi pass; Linux pending | Native Codex manifest and skill validators pass; temp-prefix install, upgrade, and uninstall preserve learner data; Pi 0.85.1 accepts the shared skill. Linux packaging awaits a Linux runner. |
| A21 | Pass | Existing LeetCode unit/integration suites pass; Kattis now has a fixture-controlled regression suite. |
| A22 | Pass with authenticated checks not run | Dated public reads pass for both providers. Authenticated reads, remote runs, and real submissions were not run because they require explicit account authorization. |

## Remaining release evidence

Run `make test` on a supported Linux host and append its OS, Odin version, and
results here. Authenticated provider checks remain opt-in. A learner study with
pre/post and delayed transfer tasks is also still required before making any
claim that the product improves learning; technical acceptance does not prove
educational effectiveness.
