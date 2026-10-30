---
name: status
description: Report learn-anything progress without changing anything. With no topic, list every topic in the learning folder with its status and current section; with a topic, show its sections, how far each has got, and the next step. Use when the learner asks where they are, what they are learning, or how far a learn-anything topic has got.
---

# Learn Anything: status

Read-only: do not start a drill, ask practice questions, or edit any file. The state files are described in [../start/references/formats.md](../start/references/formats.md). Find the `.learning/` folder as the `start` skill does, in the current folder or the nearest one above it; with none, say so and suggest `start`.

**No topic named:** list every folder in `.learning/` that has a `state.md` or `agent-state.md`, in-progress topics first, then done, then skipped:

```text
topic              mode   status       current section   last session
postgres-indexing  human  in-progress  Mental models     2026-10-26
```

**A topic named** (its slug or map title), show:

- its status, and the `scope:` line from `map.md`;
- each section with its status and how many of its items are Solid, Shaky, and Unseen, with the current section marked;
- the Shaky items and their notes, if there are only a few;
- the `next:` from the last session-log line.

For an agent-mode topic, show its status, baseline, how many answers were checked, the gaps by kind, and whether the skill was written and installed.

Counts are progress, not a score: do not turn them into percentages or grades. End by saying what `start` would do next (continue the current section, or pick a next topic) without doing it.
