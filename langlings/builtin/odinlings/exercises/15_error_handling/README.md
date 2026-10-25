# Error handling

Odin has no exceptions. Errors are ordinary values, returned as the last
result:

- a `bool`, as in `value, ok := strconv.parse_int(s)`
- an enum whose zero value means success: `Error :: enum { None, Not_Found }`
- a union of error types, where `nil` means success

A few operators keep the plumbing short. Each looks at the last value of a
multi-value expression:

- `x := f() or_return` returns from the current procedure when the error
  isn't `nil`/`false`, passing the error up. The procedure's own last result
  must be a compatible error type.
- `x := f() or_else default` uses `default` when the call fails. It works on
  map lookups, type assertions and `(value, ok)` procedures.
- `or_continue` and `or_break` do the same inside loops, skipping to the next
  iteration or leaving the loop.

## Further information

- [or_return operator](https://odin-lang.org/docs/overview/#or_return-operator)
- [or_else expression](https://odin-lang.org/docs/overview/#or_else-expression)
- [or_continue](https://odin-lang.org/docs/overview/#or_continue-operator) and [or_break](https://odin-lang.org/docs/overview/#or_break-operator)
- Demo file: `or_else_operator`, `or_return_operator`, `or_break_and_or_continue_operators`
- [FAQ: exceptions](https://odin-lang.org/docs/faq/#exceptions)
