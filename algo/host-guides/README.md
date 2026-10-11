# Algorithm Learning host setup

The shared contract is the native `algolearn` binary plus
`skills/algorithm-learning/SKILL.md`. Hosts may use MCP or invoke the JSON CLI;
both reach the same operation registry and workspace event stream.

## Generic shell client

Build and place the binaries on `PATH`:

```sh
make build
make install PREFIX="$HOME/.local"
algolearn doctor --workspace /path/to/practice --json
```

Load the teaching skill into the agent, then allow it to run argument-array
commands of this form:

```sh
algolearn call state_get --workspace /path/to/practice --input request.json --json
```

Write JSON to a file or stdin. Do not interpolate learner text, source, or
credentials into a shell command. A text-only host without filesystem or
process access can ask the learner to run commands and paste results, but must
state that it did not execute or persist anything itself.

## Direct MCP registration

Launch the native newline-delimited stdio server with a workspace fixed by the
process configuration:

```sh
/absolute/path/to/algolearn serve --workspace /absolute/path/to/practice
```

Configure the host's local stdio MCP facility with that executable and argument
array. The compatibility target is MCP `2025-11-25`. The server exposes typed
schemas for every engine operation, returns the envelope in
`structuredContent` and an equivalent text block, and keeps diagnostics off
stdout.

Do not copy configuration keys from one host to another. If a host does not
document local stdio MCP, use the generic shell workflow.

## Codex plugin

```sh
make package-plugin
```

The assembled wrapper is `plugins/codex/algorithm-learning/`. It contains the
native binary, the shared skill, a validated plugin manifest, and `.mcp.json`.
Its launcher uses `ALGOLEARN_WORKSPACE` when set and otherwise binds the process
working directory. `ALGOLEARN_BIN` can point to a separately installed binary.

The source wrapper is intentionally marketplace-neutral. Installing or sharing
it through a marketplace is a separate host action; packaging does not modify
personal Codex settings.

## Pi shell integration

Pi 0.85.1 accepts the shared Agent Skill directly:

```sh
cd /path/to/practice
pi --skill /path/to/algo/skills/algorithm-learning
```

Keep Pi's `bash` tool enabled so it can invoke the JSON CLI. The skill-loading
path was checked offline with Pi 0.85.1 on 2026-09-20; no model call or provider
account mutation was needed for that compatibility check. Pi does not need a
separate progress store: it resumes through `algolearn session_resume` in the
practice workspace.

## Moving to another machine

Create `export_create` with `include_source=true`, copy the resulting export to
an empty practice workspace, then run `import_validate` and `import_apply` with
the validated source hash. Reconfigure provider credentials and executable
paths locally. Credentials and provider caches are intentionally absent from
the export.
