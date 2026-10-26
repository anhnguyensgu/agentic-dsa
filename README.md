# agentic-dsa

A DSA coach that lives inside your coding agent. It keeps you writing the
solution, records how much help you actually got, and schedules spaced reviews
per pattern so you can still solve it weeks later.

Three pieces:

- **`algo`**: one native command-line program. `algo judge` fetches, tests, and
  submits LeetCode and Kattis problems; `algo learn` is the tutoring engine that
  stores sessions, hints, test evidence, and reviews.
- **Agent plugins** for Claude Code, Codex, and Pi that teach your agent to use
  `algo` and `langlings`.
- **`langlings`**: a separate exercise runner for fix-the-code courses in any
  language, with the odinlings course built in.

```text
algo/       source for the algo program
plugins/    the agent plugins and their skills
langlings/  source for the langlings runner and its built-in courses
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

From the repository root of your clone (keep the clone; agents use it in place):

```sh
cd ..   # back to agentic-dsa/ after step 1

# Claude Code
claude plugin marketplace add ./plugins
claude plugin install algorithm-learning@agentic-dsa

# Codex
codex plugin marketplace add ./plugins
codex plugin add algorithm-learning@agentic-dsa

# Pi
pi install ./plugins/algorithm-learning
```

For langlings exercises, also install the `langlings` plugin the same way; see
[`plugins/README.md`](plugins/README.md#langlings).

### 3. Practise

Start the agent in the directory where you want to keep your practice (it
becomes the learning workspace) and ask, for example:

> Help me learn algorithms in Odin. I have 30 minutes. Continue from where I
> stopped and give me hints, not answers.

## More

- [`plugins/README.md`](plugins/README.md): per-agent setup details, MCP for Pi, other agents
- [`algo/README.md`](algo/README.md): `algo judge` command reference
- [`algo/learn/README.md`](algo/learn/README.md): the learning engine
- [`algo/VERIFICATION.md`](algo/VERIFICATION.md): what is tested
- [`langlings/README.md`](langlings/README.md): the langlings runner and how to add a course
