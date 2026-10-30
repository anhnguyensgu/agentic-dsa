# Survey

Build `map.md`: a map of the domain that a newcomer can read in 10–15 minutes, grounded in sources.

1. **Scope.** Choose the scope the request implies and write it on the map's `scope:` line. Narrow a very broad topic ("databases") to something mappable ("relational database internals"), and say which scope you chose so the learner can correct it; do not spend the setup question on it.

2. **Find sources**, up to 10, preferring in this order:
   - official documentation, specifications, and standards;
   - well-regarded books, guides, and courses that practitioners recommend to each other;
   - practitioner write-ups and talks (experience reports, postmortems, "what I wish I knew" pieces), the best source of common tasks and misconceptions;
   - survey or overview papers, for research fields.

   Skip content farms and unattributed listicles. For a fast-moving domain prefer current sources, and record each source's date or version. Use web search and fetch when available, and subagents to read several sources at once; otherwise use what the user provides and local documentation (see Tools in SKILL.md). Cite only what you actually read.

3. **Take notes.** When a source will be needed again, to ground drill feedback or to check agent answers, write its key points to `sources.md` so later sessions need not fetch it again.

4. **Write `map.md`** in the format in [formats.md](formats.md):
   - vocabulary: the terms a newcomer meets first in docs and discussions, not an exhaustive glossary;
   - mental models: the ideas experts use to predict and decide, each with what it is, why it matters, and a concrete example;
   - landscape: the main tools, approaches, or schools, and what each trades off;
   - common tasks: what practitioners actually spend their time doing;
   - misconceptions: what newcomers really get wrong, taken from FAQs, pitfall sections, and practitioner write-ups rather than guessed.

5. **Check before saving.** Every mental model has all three parts and a source, every landscape entry names a trade-off, no section is padded to reach a count, and the whole map reads in about 15 minutes (roughly 3,000 words at most).

6. **Initialize state.** Human mode: create `state.md` with `status: in-progress`, every map section under Sections as `not-started`, and every map item under Unseen, keeping `known:` if it is already set. Agent mode: `agent-state.md` already holds the pre-test; leave it as it is.

7. **Report** the scope, the number of sources, and what comes next (orient, or the check step in agent mode). Tell the learner they can read `map.md` at any time.

To refresh an existing map, update it in place: keep item names stable, add new items to Unseen, and change the `updated:` date.
