# Agent plugins

Each supported agent has its own plugin under `plugins/<agent>/algorithm-learning/`.
All of them wrap the same two things: the native `algo` binary (its `algo learn`
command group) and the teaching skill in `skills/algorithm-learning/`. Agents
reach one operation registry and one workspace event stream, so a session
started in one agent can be resumed in another.

| Agent | Plugin | Provides | Finds `algo` |
| --- | --- | --- | --- |
| Claude Code | `claude/algorithm-learning/` | skill + MCP server | `PATH` |
| Codex | `codex/algorithm-learning/` | skill + MCP server | bundled `bin/algo` (macOS arm64) |
| Pi | `pi/algorithm-learning/` | skill (runs the JSON CLI) | `PATH` |

Only each agent's manifest files are edited by hand. The skill copy, the
`scripts/launch_algolearn_mcp` launcher, and Codex's `bin/algo` are generated
from `skills/algorithm-learning/`, `scripts/launch_algolearn_mcp`, and
`bin/algo`:

```sh
make package-plugins   # rebuild and regenerate every plugin
make test-packaging    # validate them, including Claude's own validator when installed
```

Install `algo` on `PATH` for the Claude Code and Pi plugins:

```sh
make install PREFIX="$HOME/.local"
algo learn doctor --workspace /path/to/practice --json
```

The MCP launcher uses `ALGOLEARN_BIN` when set, then a bundled `bin/algo`, then
`algo` on `PATH`. Its workspace is `ALGOLEARN_WORKSPACE` when set, otherwise the
directory the agent started the server in.

## Claude Code

The repository root is a Claude Code marketplace
(`.claude-plugin/marketplace.json`):

```text
/plugin marketplace add anhnguyensgu/agentic-dsa
/plugin install algorithm-learning@agentic-dsa
```

For a local checkout, add the marketplace by path instead
(`/plugin marketplace add /path/to/agentic-dsa`), or load the plugin for one
session with `claude --plugin-dir algo/plugins/claude/algorithm-learning`.

The plugin adds the `algorithm-learning` skill and an `algorithm-learning` MCP
server with one tool per engine operation; `claude mcp list` shows it as
`plugin:algorithm-learning:algorithm-learning`. Start Claude Code in the
practice workspace, or set `ALGOLEARN_WORKSPACE`. The plugin adds about 100
tokens to every session (`claude plugin details algorithm-learning`).

If `~/.claude/skills/algorithm-learning` already links to the shared skill,
remove that link after installing the plugin so the skill is not loaded twice.

## Codex

The repository root is also a Codex marketplace
(`.agents/plugins/marketplace.json`):

```sh
codex plugin marketplace add anhnguyensgu/agentic-dsa   # or a local checkout path
codex plugin add algorithm-learning@agentic-dsa
```

`.codex-plugin/plugin.json` names the shared skill and `.mcp.json`, and the
launcher runs the bundled `bin/algo learn serve`. The committed binary is a
macOS arm64 build: on another platform, set `ALGOLEARN_BIN` to a locally built
`algo`, or run `make package-plugins` to rebuild the bundle. Packaging never
changes personal Codex settings.

## Pi

The Pi plugin is a Pi package that provides the skill:

```sh
pi install ./algo/plugins/pi/algorithm-learning       # personal
pi install -l ./algo/plugins/pi/algorithm-learning    # this project only
pi -e ./algo/plugins/pi/algorithm-learning            # one session, no install
```

Pi packages cannot declare MCP servers, so the skill drives the JSON CLI through
Pi's `bash` tool; keep that tool enabled. To use MCP tools instead, register the
server yourself:

```sh
pi mcp add algorithm-learning -- algo learn serve --workspace /absolute/path/to/practice
```

Pi 1.0.2 loads the packaged skill (checked with `pi --mode rpc` and
`get_commands`, without a model call). Pi resumes through
`algo learn call session_resume`; it needs no separate progress store.

## Any other agent

An agent that reads skills and runs commands can use the shared skill and the
JSON CLI directly:

```sh
algo learn call state_get --workspace /path/to/practice --input request.json --json
```

Write JSON to a file or stdin. Do not interpolate learner text, source, or
credentials into a shell command. A text-only agent without filesystem or
process access can ask the learner to run commands and paste results, but must
state that it did not execute or persist anything itself.

An agent with local stdio MCP support can launch the server directly:

```sh
/absolute/path/to/algo learn serve --workspace /absolute/path/to/practice
```

The compatibility target is MCP `2025-11-25`. The server exposes typed schemas
for every engine operation, returns the envelope in `structuredContent` and an
equivalent text block, and keeps diagnostics off stdout. Do not copy
configuration keys from one agent to another; if an agent does not document
local stdio MCP, use the JSON CLI.

## Moving to another machine

Create `export_create` with `include_source=true`, copy the resulting export to
an empty practice workspace, then run `import_validate` and `import_apply` with
the validated source hash. Reconfigure provider credentials and executable
paths locally. Credentials and provider caches are intentionally absent from
the export.
