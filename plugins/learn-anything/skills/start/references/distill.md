# Distill

Agent mode: turn the Gaps in `agent-state.md` into a skill that tells a model what it gets wrong about the domain. Write it to `.learning/<slug>/skill/SKILL.md` in the format in [formats.md](formats.md).

- **Gaps only.** Leave out everything the drill got right: the model already knows it, and repeating it costs context in every session that loads the skill.
- **Source every claim** with a full URL.
- **Write for use.** State each item as a fact or instruction a model can act on while working ("`foo()` was removed in 3.0; use `bar()`"), not as a quiz result.
- **Make the description specific.** Name the concrete triggers (tools, file types, commands, tasks) so the skill loads when the domain comes up and not otherwise.
- **Keep it small.** Under about 150 lines, with detail moved into `skill/references/`.
- **Do not pad.** If the gaps are few or minor, say so and ask whether the skill is worth installing.

- **Complement the baseline.** When `agent-state.md` names a baseline skill, cover only what it still gets wrong or lacks, under a different name. Never edit the baseline itself.

Then **offer to install** it in the current project, not globally: `.claude/skills/<name>/` for Claude Code, `.agents/skills/<name>/` for Codex and other agents that read that folder. A different name matters: in Claude Code, a personal skill hides a project skill of the same name. When the host has a skill generator (a skill-creator skill or command), use it to package and validate the skill from `.learning/<slug>/skill/`, and keep it from adding general knowledge; otherwise copy the folder yourself. Never overwrite an existing skill without asking. Mention that the skill reflects the gaps of the model that drilled; used with another model, it may miss that model's gaps.

Once the user has installed or declined the skill, set `status: done` in `agent-state.md` and add a session-log line.
