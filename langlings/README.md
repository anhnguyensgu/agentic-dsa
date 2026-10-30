# langlings

One runner for fix-the-code exercises in any language. The engine (watching,
checking, hints, progress) is written once; each course is a TOML file in
`tracks/`.

```sh
# install (or: make -C algo install-langlings)
(cd langlings && go build -o ~/.local/bin/langlings .)

# learn Zig from an empty folder
mkdir learn && cd learn
langlings add ziglings              # clones ziglings, writes tracks/ziglings.toml
langlings ziglings                  # start

langlings add                       # every course you can add
langlings list                      # tracks and progress
langlings ziglings                  # work through a track, re-checks on save
langlings hint                      # hint for the current exercise
langlings run rustlings iterators1  # check one exercise once
langlings verify rustlings          # re-check everything, fix up progress
langlings reset                     # restore the current exercise as it shipped
langlings import ziglings ziglings  # regenerate a track from a course folder
```

`langlings` works from any folder under the one holding `tracks/`. Tracks
point at the course files where they are; the only thing langlings saves is
`.langlings/progress.json`.

## Courses

`langlings add NAME` sets up a course in one of three ways:

| Kind | Example | Where it comes from | `reset` restores from |
| --- | --- | --- | --- |
| built in | odinlings | ships inside langlings (`builtin/`) | the built-in copy |
| git | ziglings | `git clone` of its repository | the clone's git history |
| cli | rustlings | the course's own tool (`rustlings init`) | git, once you commit it |

A built-in course is a folder in `builtin/` with a `track.toml` (its `root`
is `"../<name>"`), an `exercises/` folder and a `README.md`; those three are
embedded when langlings is built, while anything else there, such as
solutions, stays in the source. Re-running `add` never overwrites an exercise
you've edited, so it's also how you pick up new ones. External courses are
listed in `courses` in `import.go`, each with an importer that turns the
course's own files into a track.

## Adding a language

Write `tracks/<name>.toml`. No code changes.

```toml
root = "../go-exercises"          # where commands run, relative to this file
run  = "go run {file}"            # {file} and {name} come from each exercise
test = "go test {file}"
stream = "stdout"                 # which output `expect` is compared to

[[exercise]]
name   = "hello"
file   = "hello.go"
expect = "Hello, world!"          # optional: required output
hint   = "fmt.Println prints a line."

[[exercise]]
name   = "stack"
file   = "stack_test.go"
mode   = "test"                   # use the `test` command
readme = "stack.md"               # shown as "Read: ..." when you reach it
```

An exercise passes when its command exits 0 and, if `expect` is set, the
output matches it (trailing whitespace ignored). Commands run directly, not
through a shell, so a track works the same on every OS: chain steps with `&&`,
but pipes, redirects and quoted arguments aren't supported. Other per-exercise fields:
`cmd` replaces the track's command, `stream` overrides the track's, and
`skip = true` leaves the exercise out.
