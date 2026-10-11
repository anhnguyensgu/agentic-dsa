# Algorithm practice tools in Odin

A terminal workflow for finding problems, preparing solutions, practising in
Odin, and learning persistently across Kattis and LeetCode.

`algolearn` is the evidence-backed tutor engine: durable sessions and attempts,
hint accounting, bounded local execution, honest assessment, spaced review,
cross-agent handoff, native MCP, portable teaching skill, and provider job
recovery. Start with [the Algorithm Learning guide](algolearn/README.md) and see
[the verification report](VERIFICATION.md) for exact tested scope.

The provider CLIs remain useful directly. The rest of this document describes
the LeetCode workflow; `bin/kattis help` describes the corresponding Kattis
machine and terminal interface.

## Build and install

Requires Odin and `curl` on `PATH`. Developed and tested on macOS with
`dev-2026-07:819fdc7a8` (Homebrew 2026-07a). Uses the current `core:os` API.

```sh
make build
./bin/leetcode help
make install                 # ~/.local/bin/{leetcode,kattis,algolearn}
# Or: make install PREFIX=/your/prefix
```

Add `~/.local/bin` to your shell's `PATH` if necessary. Each CLI is one native
executable; Python is needed only for the integration tests. `make check`
type-checks every package with `-vet -strict-style`; `make test` runs it along
with the unit and integration suites.

## Project layout

Each directory is one Odin package. The executables import the shared
package by relative path, so plain `odin build <dir>` works without
collection flags.

| Package | Kind | Contents |
| --- | --- | --- |
| `leetcode/` | executable | LeetCode CLI: `cli.odin` (command and flag tables), `api.odin` (curl transport), `problems.odin`, `judge.odin`, `workspace.odin` (scaffolding and local tests), `account.odin`, login in `auth_server.odin`, `cookies.odin`, `config.odin`, `verify.odin` |
| `kattis/` | executable | Kattis CLI: `cli.odin`, `http.odin`, `html.odin` (page parsers), `problems.odin`, `local_test.odin`, `auth.odin`, `submit.odin` |
| `algolearn/` | executable | Learning engine front ends: `main.odin` (CLI) and `mcp.odin` (MCP stdio server) |
| `algolearn/learning/` | library | The engine: event store (`store.odin`, `events.odin`), projection (`projection.odin`), operation registry (`operations.odin`), and one file per operation group |
| `safeio/` | library | Shared OS safety code: owner-only atomic file writes and bounded child processes with a credential-free environment |

Conventions used throughout:

- Errors are small enums or unions whose zero value is `nil`, propagated with `or_return`.
  Each tool prints details at the failure site and a one-line summary from `run`.
- `main` calls `run`, which owns an arena for the whole command and returns the
  exit code. Nothing is freed individually. The MCP server gives each message
  and each tool call its own arena.
- Lookup tables are enumerated arrays (`[Command]Command_Spec`, `[Error]string`),
  and flag sets are `bit_set`s.
- JSON documents are typed structs marshaled with `core:encoding/json`. Struct
  field order is the wire order.

## Find a problem

```sh
leetcode list
leetcode list "binary search" --difficulty Easy --tag array --free
leetcode list --status todo --limit 25 --skip 25
leetcode show 1
leetcode show two-sum
leetcode show https://leetcode.com/problems/two-sum/
leetcode daily
leetcode random --difficulty Medium --tag tree --free
leetcode languages two-sum
leetcode open two-sum
```

`list` supports `--difficulty Easy|Medium|Hard`, repeatable `--tag <slug>`,
`--status ac|notac|todo`, `--free`, `--limit 1..100`, and `--skip <offset>`.
Progress filters require login. `search` aliases `list`; `fetch` aliases `show`.
Numeric references are **frontend problem IDs**, not internal judge IDs.
`--free` collects the matching catalogue before filtering/pagination because
this LeetCode endpoint cannot exclude paid questions itself. Broad free-only
queries can take longer; a search, difficulty, or topic filter reduces the work.

Data commands accept `--json`; diagnostics go to stderr. Flags that do not apply
to a command are errors. Quote search phrases and paths containing spaces.

## Log in

Public problem browsing does not require an account. Login enables account
progress, Premium content you have access to, remote runs, and submissions.

```sh
leetcode auth
leetcode status
leetcode status --json
leetcode logout
```

The browser flow listens on `127.0.0.1:9777` for up to two minutes. If LeetCode
does not complete the redirect, use `leetcode paste`. In your browser's DevTools,
copy the `LEETCODE_SESSION` and `csrftoken` cookie values from leetcode.com, then
paste this line into the prompt:

```text
LEETCODE_SESSION=<value>; csrftoken=<value>
```

Both values are needed for `run` and `submit`. A session token alone suffices for
read-only account queries. Piped input also works; avoid placing cookies in shell
arguments/history. Credentials are verified before saving and stored at
`~/.config/leetcode-odin/config.json`, with mode `0600`. Writes atomically replace
the previous file. HTTP headers and source code are sent through private
temporary files, not command-line arguments. Temporary request files are removed
after each request. `logout` removes only the credentials, not cached data or
your solutions.

## Practice in Odin

```sh
leetcode pick two-sum
# Edit problems/1-two-sum-odin/solution.odin
leetcode test problems/1-two-sum-odin
```

`pick` creates a fresh directory containing:

| File | Purpose |
| --- | --- |
| `README.md` | Problem statement and source link |
| `problem.json` | Full fetched problem metadata and language snippets |
| `solution.odin` | Solution procedure to implement |
| `runner.odin` | Local test harness and argument decoding |
| `cases.json` | Editable local cases and expected outputs |
| `input.txt` | LeetCode-format examples, one argument per line |

The generator creates typed signatures for integers, floats, booleans, strings,
characters (represented as strings), and nested arrays. Parameter names are
`arg0`, `arg1`, etc.; comments retain LeetCode's names. Return allocated arrays,
not slices of stack-local compound literals. The harness owns a command arena.

For design problems and specialized node types, `solve` receives
`[]json.Value` and returns `json.Value`. Lists, trees, and graphs keep LeetCode's
serialized representation, including `null` entries; convert these to your own
Odin structs inside your solution if desired. For design questions, the input
contains the operation names and argument arrays. This also lets you adapt
custom problem-specific validation in the generated runner.

An editable case looks like this:

```json
[
  {
    "name": "Example 1",
    "input": [[2, 7, 11, 15], 9],
    "expected": [0, 1],
    "check": true,
    "unordered": true
  }
]
```

Each `input` element is one function parameter. Example outputs are extracted
when they are valid single-line JSON. Review `cases.json`: non-JSON outputs and
custom-judge rules need manual expected values or a custom comparator.
`check: false` prints the result as **UNVERIFIED** and makes `test` exit with code
4. It never counts an unchecked case as passed. JSON `null` is a valid expected
value when `check` is true.

Comparison is structural, with exact integers and a `1e-6` relative/absolute
float tolerance. `unordered: true` ignores only the outermost array order and
preserves duplicate counts. Use it for results such as Two Sum indices. For
common void-returning array/matrix problems, the harness compares the mutated
first argument. Other custom return conventions need an adapter in `runner.odin`.

`test --timeout 10 <directory>` bounds each of the compile and execution phases
to ten seconds. The default is 60 seconds per phase. A failed compilation,
runtime failure, or wrong result exits nonzero. Local examples are a learning
tool; passing them does not prove acceptance against LeetCode's hidden tests.
Add `--json` for a structured report with verified passed/failed and unchecked
counts. Compiler and learner output are bounded to 256 KiB, and local child
processes do not inherit provider credential environment variables.

## Run and submit supported languages

Odin is not a LeetCode judge language. Select a language offered by
`leetcode languages <problem>` to use the remote judge.

```sh
leetcode pick two-sum --lang python3
# Edit problems/1-two-sum-python3/solution.py
leetcode run two-sum problems/1-two-sum-python3/solution.py
leetcode run two-sum problems/1-two-sum-python3/solution.py --input my-cases.txt
leetcode submit two-sum problems/1-two-sum-python3/solution.py
leetcode check 123456789 --timeout 120
```

`run` sends all available examples by default. A custom input file uses the same
format as LeetCode's testcase editor: one JSON value per argument, then the next
case's arguments. The language is inferred from the file extension when
unambiguous; use `--lang` for SQL dialects or another ambiguous extension.
Python `.py` defaults to `python3`.

`submit` creates an actual submission on your account. Submission requests are
sent once and are never retried automatically. Both commands print a job ID to
stderr and poll until the judge finishes or `--timeout` elapses. Use `check` with
the printed ID to resume a timed-out job without submitting again. Runtime,
memory, compiler/runtime diagnostics, testcase comparisons, and failed inputs
are shown when returned by LeetCode. A successful execution with incorrect
output still exits with the failed-solution code.

Machine integrations use `run-start` or `submit-start` with `--json` to receive
the durable job ID before polling, then call `check`. This is the boundary used
by `algolearn`; it prevents a resumed agent from creating a second submission.

## Account history and statistics

```sh
leetcode submissions two-sum --limit 20 --skip 0
leetcode submission 123456789 --json
leetcode stats
leetcode stats some-username --json
```

History and submission details require your session. `stats` without a username
uses the signed-in account; public profile statistics accept an explicit name.
Submission details can contain source code, so take care when redirecting or
sharing the output.

## Workspaces and offline use

```sh
leetcode pick 1 --workspace ~/practice
leetcode pick two-sum --dir ./second-attempt --lang rust
leetcode show two-sum --offline
leetcode list "binary search" --offline
leetcode random --offline --difficulty Easy
leetcode show two-sum --refresh
```

The default workspace is `./problems`, relative to the current directory.
`--workspace` overrides it for that command. A destination that already exists
is never overwritten; choose a fresh `--dir` for another attempt or language.

Problem details are read from the local cache unless `--refresh` is requested.
Online list/daily commands fetch fresh data. Offline list queries require the
same search, filters, limit, and offset to have been cached; offline random
chooses among downloaded problems and supports difficulty/tag/free filters.
Offline random cannot filter account progress. Offline daily shows the cached
challenge's date, which may be old. Missing or malformed cache data produces an
error. Remote judge and account commands always require a connection.

Cache files live under `<workspace>/.cache` with mode `0600`. They can include
problem text, Premium content, and cached progress from the session used to fetch
them. Treat the workspace as private; use separate workspaces for separate
accounts. Logout does not erase these local snapshots. Never add credentials
or private workspace caches to a repository.

| Environment variable | Purpose |
| --- | --- |
| `LEETCODE_ODIN_CONFIG` | Alternate credentials file; useful for isolated profiles |
| `LEETCODE_ODIN_WORKSPACE` | Default workspace root |
| `LEETCODE_ODIN_NO_BROWSER` | Print browser URLs without launching a browser |

Exit codes: `0` success, `1` operational error/timeout, `2` usage error,
`3` solution failure, `4` local cases without expected outputs.

## Verification and troubleshooting

```sh
make test
python3 tests/live_smoke.py             # public API, isolated credentials
python3 tests/live_smoke.py --account   # add reads using your existing session
python3 tests/live_smoke.py --run       # execute the included example solution
```

Odin tests cover cookie parsing, callback transport/deadlines, credential storage,
argument validation, response validation, judge verdicts, and scaffold generation.
The Python integration suite builds the real CLI against a loopback mock API and
exercises login, cache/offline use, query payloads, scaffolding, actual compiled
Odin solutions, wrong answers, timeouts, remote run/submit/check, history, and
logout. It uses synthetic credentials and a temporary workspace, and makes no
real submissions.

Live smoke tests use a temporary workspace. The optional `--run` sends the
included Two Sum fixture to LeetCode's example runner; it does not create a
submission. The public reads, authenticated reads (including submission detail),
and a three-example remote run were verified against leetcode.com during
development. Actual submission creation is covered by the mock suite, not by
creating a test submission on your account.

LeetCode's website APIs are not a published stable contract. An HTTP 403 may mean
an expired session, rejected CSRF token, or a browser challenge. Log in through
your browser and refresh both cookie values. HTTP 429 means wait before retrying.
The CLI reports GraphQL errors and unexpected/non-JSON responses without dumping
remote response bodies. It does not bypass browser challenges or Premium access.

If `auth` cannot bind port 9777, close the other listener or use `paste`.
If `odin` or `curl` cannot be found, check the `PATH` in the terminal running the
CLI. The current implementation targets leetcode.com; leetcode.cn is not yet
supported. OS process deadlines were verified on macOS; other platforms should
run the integration suite before use.
