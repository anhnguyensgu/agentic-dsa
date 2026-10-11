# LeetCode tools

Build the existing Odin client into a complete terminal practice workflow.
The implementation lives in `leetcode/`; `tools/` is an earlier experiment.

## Required workflow

- [x] Installable CLI with help, strict argument validation, JSON output, and documented exit codes.
- [x] Browser/cookie login, status, logout, private credential storage, and authenticated requests.
- [x] Browse/search with difficulty, topic, status, paid/free filters and pagination.
- [x] Read a problem by slug, URL, or frontend ID; daily/random selection; language listing; browser opening.
- [x] Cache public problem data for explicit offline use; refresh on demand.
- [x] Create a problem workspace with description, metadata, examples, and language starter code without overwriting solutions.
- [x] Local Odin practice with generated sample harness, editable cases, useful failures, and time limits.
- [x] Remote run with default/custom inputs; submit and poll; resume checking by ID; report judge failures accurately.
- [x] Submission history/details and user statistics.
- [x] Reproducible unit and mock-service integration tests, plus live public-service smoke tests.
- [x] README with setup, complete command examples, authentication, limitations, and troubleshooting.

## Verification boundaries

LeetCode has no published stable API contract. Verify public queries against the
live service and exercise authenticated workflows against a local mock service.
Do not create a real account submission solely to test the client. Record the
distinction in the final verification notes. Odin is a local practice language;
remote submission languages come from the problem's own code snippets.

## Completion evidence — 2026-09-19

| Requirement | Evidence |
| --- | --- |
| Build/install/arguments | `make build`; `make install PREFIX=<temporary directory>` followed by installed `leetcode version`; parser unit tests and integration error/JSON checks |
| Authentication and private storage | Cookie/config/callback tests; mock paste/status/logout including file mode and rejected credentials; live session verification |
| Browse/filter/page/select | Live smoke: search, numeric ID, daily, random, languages; live progress-filter queries; mixed paid/free query validated; capped-page mock verifies filtered totals and offsets |
| Offline/cache/refresh | Integration checks no HTTP request for offline list; offline detail/daily/random, cache miss, corrupt detail, refresh; live offline read |
| Scaffolds/no overwrite | Integration creates Odin and Python workspaces, checks generated files, rejects existing destination without changing source |
| Odin local runner | Compiled passing and failing solutions; order-insensitive output; unverified cases; timeout; generic design input; nested-array in-place mutation; string/bool/float parameters; empty cases rejected |
| Remote run/submit/check | Mock request payload/header checks, custom input, dotted run IDs, submission IDs, pending polling, resume, timeout, wrong-answer and compile-error exits; live Two Sum run passed all three examples |
| History/profile | Live history and submission-detail reads; live statistics; mock authenticated and public variants |
| Reproducible verification | `make test`: 19 Odin unit tests and 64 CLI integration checks pass; `odin check leetcode -vet -strict-style` passes |
| Documentation | `README.md` covers all commands, build/install, auth, cache/privacy, local JSON contract, exit codes, examples, and limitations |

Actual account submission creation was not performed: that path is verified with
the local mock service. Browser redirect transport is covered by loopback tests;
manual browser sign-in is an interactive fallback with cookie paste available.
No changes were made to the pre-existing `.algo` study data or `tools/` experiment.
