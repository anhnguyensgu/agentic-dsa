# odinlings

Small exercises for getting used to reading and writing Odin, in the spirit
of [rustlings](https://github.com/rust-lang/rustlings) and
[ziglings](https://codeberg.org/ziglings/exercises). Each exercise is one
file that doesn't work yet: it fails to compile, fails its tests, or prints
the wrong thing. Fix it, save, and move on.

The order follows the [Odin overview](https://odin-lang.org/docs/overview/)
and the [demo file](https://odin-lang.org/docs/demo/), from variables to
threads, SoA layouts and calling C. Every topic folder has a README with the
idea in brief and links to the matching overview sections.

## Running it

Odinlings is built into the `langlings` runner. `langlings add odinlings`
writes the exercises to `odinlings/` and the track to `tracks/odinlings.toml`
in the folder you run it from:

```sh
langlings add odinlings      # set up the course (safe to re-run: keeps your answers)
langlings odinlings          # watch mode: re-checks the current exercise on save
langlings hint odinlings     # hint for the current exercise
langlings list odinlings     # every exercise and your progress
```

Each exercise is built as a single file, which you can also do by hand:

```sh
odin run exercises/01_variables/variables1.odin -file
odin test exercises/02_procedures/procedures5.odin -file
```

Tests in this course run with `-define:ODIN_TEST_FAIL_ON_BAD_MEMORY=true`, so
a leak or a bad free fails the test. That's on purpose: owning your memory is
a big part of writing Odin. Builds go into `.build/`, which git ignores.

Every file is `package main`, so an editor that treats a folder as one
package may complain about duplicate declarations. The compiler doesn't,
because it builds one file at a time.

## Layout

```text
exercises/NN_topic/README.md   the topic, briefly, with links
exercises/NN_topic/*.odin      the exercises, in order
exercises/quizzes/             quiz1-3, which combine several topics
solutions/                     one solution per exercise, same paths
track.toml                     the langlings track: order, commands, hints
dev/verify.sh                  checks the course itself
```

Only `exercises/`, this README and `track.toml` are built into langlings;
the solutions and `dev/` stay here.

| Topics | Covers |
| --- | --- |
| 00-04 | intro, variables, procedures, control flow, `defer` and `when` |
| 05-09 | primitive types, arrays, slices and dynamic arrays, structs, pointers |
| 10-14 | enums, unions and `Maybe`, strings, packages, maps, quiz1 |
| 15-17 | error handling (`or_return`, `or_else`, ...), memory and allocators, the context, quiz2 |
| 18-23 | generics, procedure values, bit sets and bit fields, tests, iterators, threads |
| 24-29 | SoA, reflection and `any`, conversions, matrices and quaternions, vet, C interop, quiz3 |

## Working on the course

After adding or changing an exercise, run:

```sh
./dev/verify.sh
```

It checks that every solution passes and that every exercise fails as
shipped, unless the exercise is identical to its solution (`intro1`). It
works on a temporary copy, so your progress isn't touched. A new exercise
needs a file in `exercises/`, its solution at the same path in `solutions/`,
and an `[[exercise]]` entry in `track.toml`. Rebuild langlings afterwards so
the built-in copy has it.

Written against `odin version dev-2026-10`.
