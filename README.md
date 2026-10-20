# agentic-dsa

A DSA coach that lives inside your coding agent. It keeps you writing the
solution, records how much help you actually got, and schedules spaced reviews
per pattern so you can still solve it weeks later.

Two pieces:

- **`algo`**: one native command-line program. `algo judge` fetches, tests, and
  submits LeetCode and Kattis problems; `algo learn` is the tutoring engine that
  stores sessions, hints, test evidence, and reviews.
- **One agent plugin** for Claude Code, Codex, and Pi that teaches your agent to use it.

```text
algo/       source for the algo program, the teaching skill, and the plugins
problems/   practice solutions
```

## Install

### 1. Build `algo`

Requires [Odin](https://odin-lang.org) (`dev-2026-07` or later), `curl`, and `make`.

```sh
git clone https://github.com/anhnguyensgu/agentic-dsa.git
cd agentic-dsa/algo
make install                    # installs to ~/.local/bin; add it to PATH
algo learn doctor --workspace . --json
```

### 2. Add the plugin to your agent

**Claude Code** (inside a session):

```text
/plugin marketplace add anhnguyensgu/agentic-dsa
/plugin install algorithm-learning@agentic-dsa
```

**Codex**:

```sh
codex plugin marketplace add anhnguyensgu/agentic-dsa
codex plugin add algorithm-learning@agentic-dsa
```

The Codex plugin bundles a macOS arm64 build of `algo`; on other platforms set
`ALGOLEARN_BIN` to the one you built.

**Pi** (from your clone):

```sh
pi install ./algo/plugins/algorithm-learning
```

### 3. Practise

Start the agent in the directory where you want to keep your practice (it
becomes the learning workspace) and ask, for example:

> Help me learn algorithms in Odin. I have 30 minutes. Continue from where I
> stopped and give me hints, not answers.

## More

- [`algo/plugins/README.md`](algo/plugins/README.md): per-agent setup details, MCP for Pi, other agents
- [`algo/README.md`](algo/README.md): `algo judge` command reference
- [`algo/learn/README.md`](algo/learn/README.md): the learning engine
- [`algo/VERIFICATION.md`](algo/VERIFICATION.md): what is tested
