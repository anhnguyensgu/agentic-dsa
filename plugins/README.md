# Agent plugins

Three plugins serve Claude Code, Codex, and Pi (and the skill and MCP server
also work in [DeepTutor](#deeptutor)): `algorithm-learning/` for DSA
tutoring with `algo`, `langlings/` for coaching fix-the-code language exercises
(see [langlings](#langlings)), and `learn-anything/` for getting familiar with
any domain (see [learn-anything](#learn-anything)). Each holds the only copy of its skill,
and each agent reads its own manifest from the same folder:

```text
plugins/
├── .claude-plugin/marketplace.json   Claude Code marketplace (lists all plugins)
├── .agents/plugins/marketplace.json  Codex marketplace (lists all plugins)
├── algorithm-learning/               the algo plugin
│   ├── skills/algorithm-learning/    the teaching skill (edit here)
│   ├── scripts/launch_algolearn_mcp  starts `algo learn serve` (edit here)
│   ├── .claude-plugin/plugin.json    Claude Code: skill + MCP server (inline)
│   ├── .codex-plugin/plugin.json     Codex: skill + MCP server (.mcp.json)
│   ├── .mcp.json                     Codex's MCP config
│   └── package.json                  Pi: skill
├── langlings/                        the langlings plugin: skill only
│   ├── skills/langlings/             the coaching skill (edit here)
│   ├── .claude-plugin/plugin.json    Claude Code
│   ├── .codex-plugin/plugin.json     Codex
│   └── package.json                  Pi
└── learn-anything/                   the domain-learning plugin: skill only
    ├── skills/start/                 the workflow skill (edit here)
    ├── skills/status/                the read-only progress report
    ├── .claude-plugin/plugin.json    Claude Code
    ├── .codex-plugin/plugin.json     Codex
    └── package.json                  Pi
```

Every agent reaches the same stateless `algo learn` tools. The tools store
nothing: each result lists the events it produced, and the agent keeps them in
its own memory. To continue a session in another agent, give it that record.

Everything agent-specific lives here. Install from a clone of this repository:
Claude Code and Codex only read a marketplace at a GitHub repository's root, so
`marketplace add owner/repo` does not find one in `plugins/`. A local
marketplace is used in place, so keep the clone where it is.

The plugin ships no binary. Build and install `algo` first; every agent needs it:

```sh
cd algo
make install          # ~/.local/bin/algo
algo learn doctor --workspace /path/to/practice --json
make test-packaging   # validate the plugin, including Claude's own validator when installed
```

The MCP launcher runs `ALGOLEARN_BIN` when set, else `algo` on `PATH`, else
`~/.local/bin/algo` (agent apps started outside a shell may not have that
directory on `PATH`). Its workspace is `ALGOLEARN_WORKSPACE` when set, otherwise
the global algo workspace (`ALGO_WORKSPACE`, else `~/algo`).

## Claude Code

From the repository root:

```sh
claude plugin marketplace add ./plugins
claude plugin install algorithm-learning@agentic-dsa
```

Inside a session, use `/plugin marketplace add /path/to/agentic-dsa/plugins`.
To try the plugin for one session without installing it, run
`claude --plugin-dir plugins/algorithm-learning`.

The plugin adds the `algorithm-learning` skill and an `algorithm-learning` MCP
server with one tool per operation; `claude mcp list` shows it as
`plugin:algorithm-learning:algorithm-learning`. It uses the global algo
workspace; set `ALGOLEARN_WORKSPACE` to use another one. The plugin adds about 100
tokens to every session (`claude plugin details algorithm-learning`).

If `~/.claude/skills/algorithm-learning` links to this skill, remove that link
after installing the plugin so the skill is not loaded twice.

## Codex

From the repository root:

```sh
codex plugin marketplace add ./plugins
codex plugin add algorithm-learning@agentic-dsa
```

`.codex-plugin/plugin.json` names the skill and `.mcp.json`, which starts the
same launcher. Installing the plugin never changes other Codex settings.

## Pi

The plugin folder is also a Pi package that provides the skill:

```sh
pi install ./plugins/algorithm-learning       # personal
pi install -l ./plugins/algorithm-learning    # this project only
pi -e ./plugins/algorithm-learning            # one session, no install
```

Pi packages cannot declare MCP servers and Pi ignores the other manifests, so
the skill drives the JSON CLI through
Pi's `bash` tool; keep that tool enabled. To use MCP tools instead, register the
server yourself:

```sh
pi mcp add algorithm-learning -- algo learn serve --workspace /absolute/path/to/practice
```

Pi 1.0.2 loads the packaged skill (checked with `pi --mode rpc` and
`get_commands`, without a model call). Pi keeps the returned events itself, as
the skill's `references/events.md` describes.

## DeepTutor

[DeepTutor](https://github.com/HKUDS/DeepTutor) is a host agent with its own
memory, web UI, and model providers (including ChatGPT-plan sign-in through its
OpenAI Codex provider). It takes `algo` as a stdio MCP server and the skill as
an ordinary `SKILL.md` package. Connect `algo` through MCP. As a CLI App it
works, but DeepTutor offers chat only the CLI Apps listed in its bundled
CLI-Anything catalog, and `algo` is not listed. With an `algo` entry added to
that catalog for one test process, DeepTutor's installer installed `algo` (a
pip package whose `algo` command runs the real binary), and a chat turn loaded
`cli_algo` and ran `algo learn doctor` through it. Running CLI Apps on macOS
also needs `DEEPTUTOR_SANDBOX_ALLOW_SUBPROCESS=1`, since there is no other
sandbox. A permanent CLI App would need `algo` in the upstream CLI-Anything
catalog.

1. Register the server. In DeepTutor, stdio MCP servers are administrator-only:
   add it under Personalization → MCP Services as the admin, or put this entry
   in `<runtime home>/data/user/settings/mcp.json`:

   ```json
   {"servers": {"algorithm-learning": {
     "command": "/absolute/path/to/algo", "args": ["learn", "serve"],
     "env": {}, "tool_timeout": 120}}}
   ```

   Use an absolute path: DeepTutor starts the server with a minimal
   environment. Add `"--workspace", "/abs/practice"` to `args`, or
   `ALGO_WORKSPACE` to `env`, for a workspace other than `~/algo`. Keep `odin`
   on the `PATH` DeepTutor is started with, or `test_run` cannot compile.
2. Add the skill: copy `algorithm-learning/skills/algorithm-learning/` into the
   active workspace's skill library,
   `<runtime home>/data/user/workspaces/<workspace id>/skills/`.
   `deeptutor skill list` then shows it as a user skill.
3. Restart `deeptutor start`. The tools appear as deferred tools named
   `mcp_algorithm-learning_<operation>`; DeepTutor's agent reads the skill
   with `read_skill` and loads them with `load_tools` when a turn needs them.

Checked on 2026-10-31 with DeepTutor 1.7.0 (PyPI, Python 3.13): its MCP probe
listed all six tools, its connection manager ran `doctor`, `curriculum_get`,
`attempt_start`, `test_run`, and a refused `submit` through its own tool
adapters, and a `deeptutor run chat` turn on `gpt-6-luna` (OpenAI Codex
provider) read the skill, loaded the tools, and answered from `doctor` and
`curriculum_get`. Whether DeepTutor's memory keeps the returned events across
sessions was not checked; ask its agent to save them, as the skill directs.

## Any other agent

An agent that reads skills and runs commands can use the shared skill and the
JSON CLI directly:

```sh
algo learn call attempt_start --workspace /path/to/practice --input request.json --json
```

Write JSON to a file or stdin. Do not interpolate learner text, source, or
credentials into a shell command. A text-only agent without filesystem or
process access can ask the learner to run commands and paste results, but must
state that it did not execute anything itself.

An agent with local stdio MCP support can launch the server directly:

```sh
/absolute/path/to/algo learn serve --workspace /absolute/path/to/practice
```

The compatibility target is MCP `2025-11-25`. The server exposes typed schemas
for every operation, returns the envelope in `structuredContent` and an
equivalent text block, and keeps diagnostics off stdout. Do not copy
configuration keys from one agent to another; if an agent does not document
local stdio MCP, use the JSON CLI.

## langlings

The `langlings` plugin is a skill only: langlings has no MCP server, so the
skill drives the `langlings` CLI (`list`, `run`, `hint`, `verify`, `reset`,
`add`) through the agent's shell tool and never starts the interactive watch
mode. It needs `langlings` on `PATH` and the course's toolchain (for example
`odin` for odinlings):

```sh
make -C algo install-langlings                  # or: make -C algo install

claude plugin install langlings@agentic-dsa    # Claude Code
codex plugin add langlings@agentic-dsa         # Codex
pi install ./plugins/langlings                 # Pi
```

Start the agent in a langlings workspace (the folder holding `tracks/`, or an
empty folder to `langlings add` a course into) and ask, for example, "help me
with the next odinlings exercise". Progress stays in langlings' own
`.langlings/progress.json`; the plugin does not record anything in `algo learn`.

## learn-anything

The `learn-anything` plugin is a skill only and needs no binary. It maps an
unfamiliar domain from fetched sources and drills it with retrieval questions
(human mode), or has the agent pre-test itself, check its answers against the
sources, and distill the gaps into a skill file (agent mode). The skill holds
the workflow only; each domain's map and state live in `.learning/<slug>/` in
the folder the agent starts in:

```sh
claude plugin install learn-anything@agentic-dsa    # Claude Code
codex plugin add learn-anything@agentic-dsa         # Codex
pi install ./plugins/learn-anything                 # Pi
```

Ask, for example, "help me get familiar with Kubernetes networking" or "learn
the current Bun test runner yourself and write a skill for it". In Claude Code,
`/learn-anything:start [topic]` starts or continues a topic and
`/learn-anything:status [topic]` shows each topic's status and current section
without changing anything. Web search,
subagents, and a question tool are used when the agent has them; without web
access, give it URLs or files to work from.

## Moving to another machine

Create `export_create` with `include_source=true`, copy the resulting export to
an empty practice workspace, then run `import_validate` and `import_apply` with
the validated source hash. Reconfigure provider credentials and executable
paths locally. Credentials and provider caches are intentionally absent from
the export.
