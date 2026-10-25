# defer and when

`defer statement` runs the statement when the enclosing scope ends, however
it ends: falling off the end, `return`, or `break`. Deferred statements run
in reverse order, and their arguments are evaluated when they run, not when
they're declared. It's how Odin keeps cleanup (`delete`, `free`, closing a
file) right next to the thing it cleans up. One thing a defer can't do is change
what a procedure returns: assigning to a named result inside a `defer` has no
effect on the caller, and Odin warns about it.

`when` looks like `if` but is decided at compile time. Its condition must be
a constant, and the branches not taken aren't even type-checked, which makes
it Odin's tool for platform-specific code. Constants can come from the
command line: `X :: #config(X, default)` reads `-define:X=value`.

## Further information

- [defer statement](https://odin-lang.org/docs/overview/#defer-statement)
- [when statement](https://odin-lang.org/docs/overview/#when-statement)
- [Conditional compilation](https://odin-lang.org/docs/overview/#conditional-compilation) and [command-line defines](https://odin-lang.org/docs/overview/#command-line-defines)
- Demo file: `control_flow` (the defer and when blocks)
