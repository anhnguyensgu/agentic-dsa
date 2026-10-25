# Control flow

Odin's control flow has no parentheses around conditions, and braces are
always required (or `do` for a one-line body).

- `if` can start with a short statement: `if v := f(); v > 0 { ... }`.
  Its variables are scoped to the whole `if`/`else` chain.
- `x if cond else y` is an expression that picks one of two values.
- `switch` runs only the matching case; no `break` is needed and nothing falls
  through unless you write `fallthrough`. Cases can be lists and ranges, and
  `case:` is the default. `switch { ... }` with no value is a tidy `if`/`else`
  chain.
- `for` is the only loop: `for i := 0; i < n; i += 1`, `for cond` (a while
  loop), `for` (forever), and range loops: `for i in 0..<n`,
  `for value, index in slice`, `for r in some_string`.
- `break` and `continue` can name a label to leave an outer loop.

## Further information

- [if statement](https://odin-lang.org/docs/overview/#if-statement)
- [Ternary operators](https://odin-lang.org/docs/overview/#ternary-operators)
- [switch statement](https://odin-lang.org/docs/overview/#switch-statement) and [fallthrough](https://odin-lang.org/docs/overview/#fallthrough-statement)
- [for statement](https://odin-lang.org/docs/overview/#for-statement), [range-based for loop](https://odin-lang.org/docs/overview/#range-based-for-loop)
- [Branch statements](https://odin-lang.org/docs/overview/#branch-statements)
- Demo file: `control_flow`
