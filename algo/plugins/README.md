# Agent plugin

One plugin, `plugins/algorithm-learning/`, serves Claude Code, Codex, and Pi.
It holds the only copy of the teaching skill, and each agent reads its own
manifest from the same folder:

```text
plugins/algorithm-learning/
├── skills/algorithm-learning/      the teaching skill (edit here)
├── scripts/launch_algolearn_mcp    starts `algo learn serve` (edit here)
├── bin/algo                        bundled macOS arm64 build (generated)
├── .claude-plugin/plugin.json      Claude Code: skill + MCP server (inline)
├── .codex-plugin/plugin.json       Codex: skill + MCP server (.mcp.json)
├── .mcp.json                       Codex's MCP config
└── package.json                    Pi: skill
```

Every agent reaches the same `algo learn` operation registry and workspace event
stream, so a session started in one agent can be resumed in another.

The two marketplace files live at the repository root, `.claude-plugin/` for
Claude Code and `.agents/plugins/` for Codex, because both agents look for them
there when installing from `owner/repo`. Each lists this folder.

```sh
make package-plugin   # rebuild bin/algo and copy it into the plugin
make test-packaging   # validate the plugin, including Claude's own validator when installed
```

The MCP launcher uses `ALGOLEARN_BIN` when set, then the bundled `bin/algo` when
it runs on this machine, then `algo` on `PATH`. Its workspace is
`ALGOLEARN_WORKSPACE` when set, otherwise the directory the agent started the
server in. Off macOS arm64, and for Pi, install `algo` on `PATH`:

```sh
make install PREFIX="$HOME/.local"
algo learn doctor --workspace /path/to/practice --json
```

## Claude Code

The repository root is a Claude Code marketplace
(`.claude-plugin/marketplace.json`):

```text
/plugin marketplace add anhnguyensgu/agentic-dsa
/plugin install algorithm-learning@agentic-dsa
```

For a local checkout, add the marketplace by path instead
(`/plugin marketplace add /path/to/agentic-dsa`), or load the plugin for one
session with `claude --plugin-dir algo/plugins/algorithm-learning`.

The plugin adds the `algorithm-learning` skill and an `algorithm-learning` MCP
server with one tool per engine operation; `claude mcp list` shows it as
`plugin:algorithm-learning:algorithm-learning`. Start Claude Code in the
practice workspace, or set `ALGOLEARN_WORKSPACE`. The plugin adds about 100
tokens to every session (`claude plugin details algorithm-learning`).

If `~/.claude/skills/algorithm-learning` links to this skill, remove that link
after installing the plugin so the skill is not loaded twice.

## Codex

The repository root is also a Codex marketplace
(`.agents/plugins/marketplace.json`):

```sh
codex plugin marketplace add anhnguyensgu/agentic-dsa   # or a local checkout path
codex plugin add algorithm-learning@agentic-dsa
```

`.codex-plugin/plugin.json` names the skill and `.mcp.json`. The launcher runs
the bundled macOS arm64 `bin/algo`; elsewhere it falls back to `algo` on `PATH`
or `ALGOLEARN_BIN`. Packaging never changes personal Codex settings.

## Pi

The plugin folder is also a Pi package that provides the skill:

```sh
pi install ./algo/plugins/algorithm-learning       # personal
pi install -l ./algo/plugins/algorithm-learning    # this project only
pi -e ./algo/plugins/algorithm-learning            # one session, no install
```

Pi packages cannot declare MCP servers and Pi ignores the other manifests, so
the skill drives the JSON CLI through
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
