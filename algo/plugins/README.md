# Agent plugin

One plugin, `plugins/algorithm-learning/`, serves Claude Code, Codex, and Pi.
It holds the only copy of the teaching skill, and each agent reads its own
manifest from the same folder:

```text
plugins/
├── .claude-plugin/marketplace.json   Claude Code marketplace (lists the plugin below)
├── .agents/plugins/marketplace.json  Codex marketplace (lists the plugin below)
└── algorithm-learning/               the plugin
    ├── skills/algorithm-learning/    the teaching skill (edit here)
    ├── scripts/launch_algolearn_mcp  starts `algo learn serve` (edit here)
    ├── .claude-plugin/plugin.json    Claude Code: skill + MCP server (inline)
    ├── .codex-plugin/plugin.json     Codex: skill + MCP server (.mcp.json)
    ├── .mcp.json                     Codex's MCP config
    └── package.json                  Pi: skill
```

Every agent reaches the same `algo learn` operation registry and workspace event
stream, so a session started in one agent can be resumed in another.

Everything agent-specific lives here. Install from a clone of this repository:
Claude Code and Codex only read a marketplace at a GitHub repository's root, so
`marketplace add owner/repo` does not find one in `algo/plugins/`. A local
marketplace is used in place, so keep the clone where it is.

The plugin ships no binary. Build and install `algo` first; every agent needs it:

```sh
make install          # ~/.local/bin/algo
algo learn doctor --workspace /path/to/practice --json
make test-packaging   # validate the plugin, including Claude's own validator when installed
```

The MCP launcher runs `ALGOLEARN_BIN` when set, else `algo` on `PATH`, else
`~/.local/bin/algo` (agent apps started outside a shell may not have that
directory on `PATH`). Its workspace is `ALGOLEARN_WORKSPACE` when set, otherwise
the directory the agent started the server in.

## Claude Code

From the repository root:

```sh
claude plugin marketplace add ./algo/plugins
claude plugin install algorithm-learning@agentic-dsa
```

Inside a session, use `/plugin marketplace add /path/to/agentic-dsa/algo/plugins`.
To try the plugin for one session without installing it, run
`claude --plugin-dir algo/plugins/algorithm-learning`.

The plugin adds the `algorithm-learning` skill and an `algorithm-learning` MCP
server with one tool per engine operation; `claude mcp list` shows it as
`plugin:algorithm-learning:algorithm-learning`. Start Claude Code in the
practice workspace, or set `ALGOLEARN_WORKSPACE`. The plugin adds about 100
tokens to every session (`claude plugin details algorithm-learning`).

If `~/.claude/skills/algorithm-learning` links to this skill, remove that link
after installing the plugin so the skill is not loaded twice.

### Claude Code on the web

Cloud sessions start from a fresh clone and do not install plugins from a
repository's marketplace, so the repository root provides the same pieces
directly: `.claude/skills/algorithm-learning` links to this skill, `.mcp.json`
starts the launcher, and `.claude/settings.json` enables that server. Its
SessionStart hook (`.claude/hooks/session-start.sh`, web only) builds Odin
`dev-2026-07` from source against the system LLVM and runs `make install`;
the first session takes about two minutes, later ones about twenty seconds.
The practice workspace is the repository root.

Locally, the same files load whenever Claude Code starts in this repository,
so a user-scope install of the plugin there shows the skill and server twice.

## Codex

From the repository root:

```sh
codex plugin marketplace add ./algo/plugins
codex plugin add algorithm-learning@agentic-dsa
```

`.codex-plugin/plugin.json` names the skill and `.mcp.json`, which starts the
same launcher. Installing the plugin never changes other Codex settings.

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
