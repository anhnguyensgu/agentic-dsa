---
name: start
description: Start or continue learning a topic with learn-anything. Get familiar with any domain fast. Build a sourced map of its vocabulary, mental models, landscape, and common tasks, then drill it with retrieval questions that carry over between sessions; or, in agent mode, learn the domain yourself and distill what you got wrong into a reusable skill. Use when someone wants to get up to speed on, get oriented in, or be quizzed on an unfamiliar field, tool, library, or practice, or asks you to learn a domain and write a skill for it. For algorithm problems use algorithm-learning; for fix-the-code language exercises use langlings.
---

# Learn Anything

The goal is familiarity, not mastery: knowing a domain's vocabulary, core mental models, landscape, and common tasks, and where to look things up.

- **Human mode** (default): the user learns; you guide and drill.
- **Agent mode**: you learn the domain and distill what you got wrong into a skill file. Use it when the user asks you to learn a domain yourself or to write a skill for it.

This skill holds the workflow only. Never add domain knowledge to it; everything about a domain lives in that domain's learning folder. Invoked with a topic, start or continue that topic; with none, see Done and the next topic. For a progress report, use the plugin's `status` skill.

## Learning folder

Each domain has a folder `.learning/<slug>/`, where `<slug>` is the domain in lowercase kebab case (`postgres-indexing`). Use the `.learning/` folder in the current folder or the nearest one above it. If there is none, confirm the folder with the user before creating `.learning/` in the current one. Inside a git repository, offer to add `.learning/` to its `.gitignore`. Reuse a domain folder whose map covers the topic instead of creating a near-duplicate.

| File | Written by | Holds |
|---|---|---|
| `map.md` | survey | the domain map, with sources |
| `state.md` | survey, orient, drill, apply | human-mode learner state |
| `agent-state.md` | self-drill | agent-mode answers, checks, and gaps |
| `sources.md` | survey (optional) | notes taken from each source |
| `skill/SKILL.md` | distill | the distilled skill |
| `apply/` | apply | practice tasks |

Read [references/formats.md](references/formats.md) before writing any of these files. They are the only memory between sessions: read them at the start, and trust them over your recollection of earlier conversations.

## Flow

```text
human:  survey (no map yet) → orient (first session) → drill ⇄ apply
agent:  pre-test → survey (no map yet) → check → distill
```

Human mode:

1. No `map.md`: run survey ([references/survey.md](references/survey.md)). A map but no `state.md`: create it ([references/formats.md](references/formats.md)).
2. No session log in `state.md` yet: ask the setup question, then orient ([references/orient.md](references/orient.md)), then drill.
3. Otherwise drill ([references/drill.md](references/drill.md)), Shaky items first.
4. Offer apply ([references/apply.md](references/apply.md)) when the learner wants practice or several mental models are Solid. It is optional.

When the learner asks for a step directly (another round, an apply task, a refresh of the map), do that instead of following the order.

Agent mode follows the self-mode section of [references/drill.md](references/drill.md), then [references/distill.md](references/distill.md). Run the pre-test before reading `map.md`, `sources.md`, or any source, even when a map already exists: once you have read them, your answers no longer show what you knew.

## Done and the next topic

A topic is done when every section in `state.md` is `done` (all its items Solid) or `skipped` by the learner; in agent mode, when distill has finished. That status, saved in the state file, is the condition for moving to the next topic.

- When the learner asks to skip a section or the whole topic, mark it `skipped` with the date straight away.
- When the last section is done or skipped, set the topic's `status: done`, add a session-log line, tell the learner, and offer a next topic: one the map's `scope:` line left out, or one the learner names.
- With no topic named, continue the `in-progress` topic with the latest session-log line. If there is none, ask for a topic.
- Asked for a new topic while another is `in-progress`, say so and ask whether to finish it first or mark it `skipped`. A skipped topic can be resumed later.

## Setup question

Human mode asks one setup question, once: which domains the learner already knows well, so explanations can be anchored to them. Store the answer as `known:` in `state.md` and do not ask again. Agent mode asks none. Questions inside orient, drill, and apply are practice, not setup, and are not limited.

## Rules

- **Practice, not evaluation.** No scores, grades, percentages, or rubrics. Each answer gets immediate feedback: what was right, what was wrong, and the correct mental model.
- **Ground in sources.** Cite only sources you read in this session or the user supplied. Never invent a title, author, or URL. Mark a claim you could not source `[unsourced]`.
- **Save state** after each round and before an interruption or likely context loss, and add a session-log line before stopping.
- **Keep the map a map.** It should read in 10–15 minutes; detail belongs in its sources.

## Tools

Every tool here is optional: use it when the host provides it, and fall back otherwise.

- **Web search and fetch** (survey, checking answers). Otherwise use URLs or files the user gives you and local documentation (`man` pages, `--help`, docs in the workspace). With no source at all, human mode can continue from your own knowledge with every claim marked `[unsourced]`, after telling the learner; agent mode stops, because there is nothing to check its answers against.
- **Subagents.** Read sources in parallel during survey; in agent mode, answer extra questions in a context that has not seen the map. Otherwise read sources one at a time and rely on the pre-test.
- **A structured question tool** for the setup question. Otherwise ask in chat.
- **A skill generator** (a skill-creator skill or command) to package and validate the distilled skill. Otherwise copy it into place yourself.
- **Practice tools** for apply. When the domain is a programming language with a langlings course, an Exercism track, or algorithm problems, offer the matching skill (langlings, algorithm-learning) instead of inventing a task.
