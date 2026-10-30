# Drill

Retrieval practice on map items. Questions exist to make the learner recall and use what they know; they are not a test.

## Human mode

**Pick a round** of 5–10 items, fewer when the learner is short of time:

1. Shaky items, those at 0 before those at 1;
2. then Unseen items in map order, mental models and the terms they depend on before the rest;
3. then one or two Solid items for spacing, when the round has room.

Leave out items in a `skipped` section.

**Choose a question type** for each item, and mix types within a round:

| Type | Asks | Suits |
|---|---|---|
| define | What is X? | terms |
| explain-why | Why does X work, or why does it exist? | models, landscape |
| predict | What happens if ...? | models |
| spot-the-mistake | Here is a flawed claim or snippet: what is wrong with it? | misconceptions, terms |
| apply | Given this scenario, what would you do or use? | models, landscape, tasks |

Revisit Shaky and Solid items with a type that makes the learner use the idea (predict, spot-the-mistake, apply) rather than restate it. Write questions from the map and its sources, not from memory alone, so the expected answer is sourced. Make scenarios and snippets concrete and realistic for the domain.

**Ask one question at a time.** The question must not contain or hint at its answer. Wait for the learner's attempt before saying anything about it. "I don't know" counts as a miss: give the answer briefly and move on.

**Give feedback right after each answer**, briefly and directly:

- confirm what was right;
- correct what was wrong or missing;
- restate the correct mental model in one or two sentences, citing the map's source when the correction matters.

No scores, no "7/10", no grades. Judge the idea, not the wording: an answer is correct when it states the core idea without a hint, and partial when it points the right way but misses the key point or needed a hint. Partial counts as a miss in `state.md`. If the learner disputes the feedback, check the sources; when they are right, fix `map.md` and say so.

Answer side questions when they come up, then continue the round.

**After the round**, update `state.md` ([formats.md](formats.md)), including section statuses: a section whose items are all Solid is done. Say in a sentence or two what is now solid and what to revisit, and name any section that just finished. When every section is done or skipped, the topic is done (see Done and the next topic in SKILL.md); otherwise offer another round, an apply task, or a stop. Before stopping, add a session-log line saying what to do next.

## Self mode (agent)

Your own drill, to find where your knowledge of the domain is wrong, out of date, or missing. Its output is the Gaps section that distill turns into a skill.

1. **Find the baseline.** Look for a globally installed skill that covers the domain: read the descriptions in the user-level skill folders (`~/.claude/skills/`, `~/.agents/skills/`, or the host's equivalent) and the skills listed in your context, matching on what a description covers rather than on its name (`odin-developer` covers Odin). Record it as `baseline:` in `agent-state.md`, or `none`. Read it before the pre-test: the gaps worth distilling are the ones left with it in place.
2. **Pre-test before reading any source.** Do not read `map.md`, `sources.md`, or any source first. Write 10–20 questions about the domain covering its vocabulary, models, tools, common tasks, and pitfalls, weighted toward what is niche or likely to have changed: versions, defaults, deprecations, renamed APIs, current conventions. Answer each from memory, with a confidence of sure or unsure. Write the questions and answers to `agent-state.md` straight away, and do not edit them later.
3. **Survey** if there is no map yet ([survey.md](survey.md)).
4. **Blind round (optional).** With a subagent tool, write questions on important map items the pre-test did not reach, give a subagent only the questions, and tell it to answer from memory without searching or reading files. Record its answers with `by: subagent`. Without a subagent, skip this step; do not answer those questions yourself after reading the map.
5. **Check** every answer against the map and its sources, fetching a source again when the map is not specific enough. Fill in `item`, `check`, and `correction`. A correction needs a source; when the sources are silent or disagree, mark the answer `unchecked` rather than guessing. Check the baseline skill's own claims the same way: one the sources contradict is a gap marked `(baseline)`.
6. **Collect gaps** in the Gaps section: every wrong, stale, or partial answer, anything the sources stress that no answer covered, and any non-obvious convention they follow. List first the wrong answers given as `sure`; they matter most.
7. Add a session-log line and continue with [distill.md](distill.md).
