# File formats

All files are Markdown in `.learning/<slug>/`. Keep the headings and field names exactly as shown so any session, in any agent, can read them. Dates are `YYYY-MM-DD`.

## Items

An item is one entry in `map.md` that can be drilled: a vocabulary term, a mental model, a landscape entry, a common task, or a misconception. State files refer to an item as `<kind>: <name>`, where kind is `term`, `model`, `landscape`, `task`, or `misconception`, and name is the entry's bold name or heading exactly as the map writes it (`model: Write amplification`). When you rename an item in the map, rename it in the state files too; when you add one, add it to Unseen.

## map.md

```markdown
# <Domain>

scope: <one line: what this map covers and what it leaves out>
updated: <date>

## Overview
<one paragraph>

## Vocabulary
- **<term>**: <one-line definition> [S1]

## Mental models
### <model name>
- What: <the model in one or two sentences>
- Why it matters: <what it lets a practitioner predict or decide>
- Example: <one concrete case>
- Sources: [S1], [S3]

## Landscape
- **<tool, approach, or school>**: <what it is>. Trade-off: <what it gains and what it costs>. [S2]

## Common tasks
- **<task>**: <what practitioners do, and with what> [S4]

## Common misconceptions
- **<the mistaken belief>**: <what is actually true> [S5]

## Sources
- [S1] <title>, <author or organization>, <date or version>, <URL or path>: <what it is best for>
```

- Sizes are upper bounds: up to 30 terms, 3–7 mental models, up to 10 sources. A narrow domain gets fewer; do not pad.
- Drop a section that does not fit the domain (a single library may have no schools to compare) rather than filling it.
- Every mental model and landscape entry cites at least one source. Other entries cite one when they can. `[unsourced]` marks a claim with none.
- Sources are listed most useful to a newcomer first. Tags are stable: a new source takes the next unused number wherever it ranks.

## state.md (human mode)

```markdown
# State: <Domain>
mode: human
status: in-progress
known: <domains the learner knows well, or "none given">

## Sections
- Vocabulary: in-progress
- Mental models: done 2026-10-28
- Landscape: skipped 2026-10-27
- Common tasks: not-started

## Solid
- model: <name> (2)

## Shaky
- term: <name> (1): right once
- misconception: <name> (0): <what was wrong, in one line>

## Unseen
- task: <name>

## Session log
- <date>: <what was covered>; next: <what to do next>
```

- `status` is `in-progress`, `done`, or `skipped`. The topic is `done` when every section is done or skipped, and `skipped` when the learner drops the whole topic. Write a status the moment it changes; a skipped topic or section the learner returns to goes back to `in-progress`.
- Sections lists the map's sections, each holding one item kind (term: Vocabulary, model: Mental models, landscape: Landscape, task: Common tasks, misconception: Common misconceptions). A section is `not-started`, `in-progress`, `done <date>` once every item in it is Solid, or `skipped <date>` when the learner says to skip it. A done section stays done when a spacing question later sends one of its items back to Shaky; the item is drilled again, but the section does not reopen.
- The current section is the first section, in map order, that is neither done nor skipped. A done topic has none.
- The number in parentheses counts correct recalls since the item's last miss.
- A correct answer adds one; at 2 the item moves to Solid.
- A partial answer or a miss sets the count to 0 and moves the item to Shaky with a one-line note on what was wrong.
- Shaky means drilled but not yet Solid, so an item answered correctly once also sits there, at 1.
- A Solid item that is missed returns to Shaky at 0.
- Every map item is in exactly one of Solid, Shaky, and Unseen.
- The session log has one line per session; it tells the next session where to pick up.

## agent-state.md (agent mode)

```markdown
# Agent state: <Domain>
mode: agent
status: in-progress
model: <the model that answered, for example claude-opus-5-5>
baseline: <name and path of the installed skill covering the domain, or none>

## Answers
### Q1. <question>
- by: pre-test | subagent
- answer: <the answer, written before reading any source>
- confidence: sure | unsure
- item: <kind: name, or "not in map">
- check: right | partial | wrong | stale | unchecked
- correction: <what the sources say> [S2]

## Gaps
- **<gap>**: <the correct statement> (wrong | stale | missing | convention) [S2]

## Session log
- <date>: <what was done>; next: <what to do next>
```

- `status` becomes `done` when distill has written the skill and the user has installed or declined it, or `skipped` when the user stops the run.
- `by`, `answer`, and `confidence` are written when the question is answered and never edited afterwards. `item`, `check`, and `correction` are filled in by the check step.
- `stale` means the answer was true for an older version or an earlier state of the field. `unchecked` means the sources do not settle it.
- Every gap cites a source. `wrong` and `stale` gaps come from answers; `missing` is something the sources stress that no answer covered; `convention` is a non-obvious practice the sources follow. A gap in the baseline skill's own claims ends with `(baseline)`.

## sources.md (optional)

```markdown
# Sources: <Domain>

## [S1] <title>
<URL or path>, read <date>
- <key point, in your words or a short quote>
```

Notes that let later sessions ground feedback and checks without fetching a source again. The map's Sources section stays the list of record; tags match it.

## skill/SKILL.md (distilled skill)

```markdown
---
name: <slug>
description: <what the skill covers and when to load it: the concrete tools, file types, commands, or tasks that should trigger it; under 1024 characters>
---

# <Domain>

Distilled on <date> by <model> from a self-drill checked against <N> sources. It covers only what that drill showed the model got wrong, had out of date, or missed; general knowledge of the domain is left out, and another model may have different gaps.

## Corrections
- <the wrong belief> → <what is true> ([source](URL))

## Recent changes
- <what changed, and since when> ([source](URL))

## Conventions and pitfalls
- <non-obvious practice or trap> ([source](URL))

## Sources
- <title>: <URL>
```

- With a baseline, the name differs from the baseline's (`<slug>-gaps`), the description says the skill complements it, and a correction to one of its claims names it ("odin-developer's … is out of date: …").
- `wrong` gaps go under Corrections, `stale` under Recent changes, and `missing` and `convention` under Conventions and pitfalls. Drop an empty section.
- Keep the file under about 150 lines; move longer material into `skill/references/<topic>.md` and link it.
- Links are full URLs, because the skill is read outside the learning folder.
