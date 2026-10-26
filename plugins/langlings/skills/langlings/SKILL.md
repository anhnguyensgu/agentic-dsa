---
name: langlings
description: Coach a learner through fix-the-code language exercises with the local `langlings` runner (odinlings, ziglings, rustlings, or any tracks/<name>.toml course). Use when a learner wants to start, continue, check, get a hint on, or reset a langlings exercise, or add a course.
---

# Langlings

`langlings` runs fix-the-code courses: each exercise is one file that fails to compile, fails its tests, or prints the wrong thing until the learner fixes it. A workspace is the folder holding `tracks/`; `langlings` finds it from any folder below, and progress lives in `.langlings/progress.json` there. Treat that file and the runner's results as authoritative; never edit the progress file by hand.

Never run bare `langlings`, `langlings watch`, or `langlings <track>`: that is the interactive watch mode, which takes over the terminal and does not exit. The learner can run it in their own terminal while you help. Use only these commands:

- `langlings list` shows tracks, progress, and each track's next exercise; `langlings list <track>` shows the exercises in order (`→` marks the current one).
- `langlings run <track> [name]` checks one exercise (default: the current one), prints its output, exits non-zero with the reason on failure, and records a pass.
- `langlings hint <track>` prints the course's hint for the current exercise.
- `langlings verify <track>` re-checks every exercise and rewrites that track's progress to match.
- `langlings reset <track> [name]` restores an exercise as it shipped and marks it unfinished. It discards the learner's edits: ask first.
- `langlings add` lists courses; `langlings add <course>` sets one up in the current folder. Adding a course without a `tracks/` above creates the workspace there, so confirm the folder first. Re-running `add` keeps edited exercises and picks up new ones.

Name the track explicitly; without one, langlings falls back to the last-used track. If `langlings` is not on `PATH`, build it from this repository's `langlings/` folder with `go build -o ~/.local/bin/langlings .` and tell the learner.

`tracks/<track>.toml` describes each exercise: `file` and `readme` are relative to the track's `root`, which is relative to the track file. Read it to find the current exercise's file, topic README, `expect`ed output, and course hint instead of guessing paths. The course's toolchain (for example `odin`, `zig`, `cargo`) must be installed for checks to pass.

Keep the learner as the author. Do not edit an exercise file unless the learner asks you to, and do not read or quote a course's solutions (for example `langlings/builtin/odinlings/solutions/`) unless they ask for the answer. When an exercise fails, run it, then help in rising steps and stop as soon as the learner can continue:

1. Point at the line or message in the compiler, test, or output diff that matters, in plain words.
2. Name the language concept involved and the topic README section that covers it.
3. Give the course hint, or your own equivalent.
4. Show a small, separate example of the concept, not the fix.
5. Give the fix only when the learner asks for it, and explain why it works.

After the learner saves a fix, run the exercise again to confirm it rather than reading the file and declaring it correct; only a pass from `langlings run` counts. When it passes, say what the exercise taught in a sentence and name the next one from `langlings list <track>`. If the learner edited exercises outside langlings or progress looks wrong, use `verify`.

A new language with no course yet needs only a `tracks/<name>.toml` file; see `langlings/README.md` in this repository for the format, and offer to write one when the learner asks.
