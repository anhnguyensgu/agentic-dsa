# AGENTS.md

`algo` is one Odin executable for algorithm practice: online judge providers
(`algo judge <provider> ...`) and an evidence-backed tutoring engine
(`algo learn ...`). Paths below are relative to `algo/`. The learner's data
lives in the global algo workspace (`$ALGO_WORKSPACE`, else `~/algo`) as
`problems/` and `.algo/`; the repository root's `../problems/` and `../.algo/`
hold earlier practice.

## Layout

```text
algo/
├── main.odin            top-level dispatch and provider list
├── judge/               shared provider core (library)
│   ├── provider.odin      Provider / Command_Spec contract, run_provider
│   ├── command.odin       `algo judge`: list, help, or run a provider
│   ├── cli.odin           argument parsing      errors.odin  errors, exit codes
│   ├── http.odin          curl transport        html.odin    HTML helpers
│   ├── runner.odin        stdin/stdout sample runner
│   ├── leetcode/          LeetCode provider (GraphQL, cache, Odin scaffold + runner)
│   ├── kattis/            Kattis provider (page parsing, login, submit, verdicts)
│   └── exercism/          Exercism provider (exercism CLI pass-through, track catalogue)
├── learn/               learning engine (library)
│   ├── operations.odin    OPERATIONS registry shared by CLI and MCP
│   ├── store.odin, events.odin, projection.odin   event store -> State
│   ├── <group>.odin       one file per operation group (sessions, jobs, reviews, ...)
│   ├── cli.odin           `algo learn` CLI      mcp.odin  MCP stdio server
│   └── README.md          engine user guide
├── safeio/              atomic owner-only writes, bounded credential-free child processes
├── curriculum/          concepts.json (concept graph; there is no bundled problem set)
├── schemas/             JSON schemas: envelope, event, export (v1)
├── plugins/             README.md is the per-agent setup guide
│   └── algorithm-learning/  one plugin for Claude Code, Codex, and Pi: the tutoring
│                            skill, MCP launcher, and one manifest per
│                            agent; plugins/.claude-plugin/ and plugins/.agents/ hold
│                            the Claude Code and Codex marketplaces
├── tests/               Python integration, MCP, packaging, teaching suites
├── README.md            CLI reference      AGENTIC_LEARNING.md  engine design spec
├── VERIFICATION.md      tested scope and expected test counts
└── PLAN.md              original LeetCode plan and completion record
```

Each directory is one Odin package imported by relative path; there is no
collection flag. Dependencies point one way:

- `main` imports `judge`, the providers, and `learn`.
- Providers import `judge` and `safeio`; `judge` never imports a provider.
- `learn` never imports providers. It re-executes its own binary as
  `algo judge <provider> ...`.

## Commands

Run from `algo/`. Requires Odin (`dev-2026-07` or later) and `curl`; Python 3
only for the integration suites.

```sh
make build        # bin/algo
make check        # odin check every package with -vet -strict-style
make test-unit    # Odin unit tests (judge, judge/leetcode, learn)
make test         # check + unit + integration + learning + MCP + packaging
odinfmt -w .      # format; no odinfmt.json, so default style
```

Before handing work back: `make check` and the narrowest test target that
covers the change (`make test` for anything cross-package).

## Conventions

- Errors are small enums or unions with a `nil` zero value, propagated with
  `or_return`. Print details where the failure happens; `run` prints a
  one-line summary and returns the exit code.
- Each command group's `run` owns one arena for the whole command; nothing is
  freed individually. The MCP server uses one arena per message and per tool call.
- Lookup tables are enumerated arrays (`[Command]Command_Spec`,
  `[Error]string`); flag sets are `bit_set`s.
- JSON is typed structs with `core:encoding/json`; field order is wire order.
- Exit codes: `0` ok, `1` operational error/timeout, `2` usage, `3` solution
  failed, `4` unverified local cases.
- Shared helpers go in the package that already uses them (usually `judge/`).
  Don't create `lib/`, `common/` or other speculative packages.

## Rules

- Always run `odinfmt -w <file>` after editing any `.odin` file, before the
  next step. Never leave an edited `.odin` file unformatted.
- Tests never create real judge submissions or use real credentials. Use the
  loopback fixtures; `tests/live_smoke.py` is opt-in and read-only by default.
- Never commit credentials, cookies, `../problems/.cache/`, or `../.algo/`.
- Don't modify the learner's solutions in `../problems/` or attempt records in
  `../.algo/` unless asked; they are evidence, not code.
- If a change alters test counts, update `VERIFICATION.md`.
- Command or flag changes must also update `README.md` (and `learn/README.md`
  for `algo learn`).
- The tutoring skill exists once, in `plugins/algorithm-learning/skills/`;
  never copy it. Keep the version in all three manifests equal to the engine
  version. Never commit a binary into the plugin; agents find `algo` through
  `make install`.
- Don't refactor code outside the task: no unrequested renames, extracted
  functions, or moved code. Prefer adding new code; if a refactor seems
  needed, say why and ask before doing it.
