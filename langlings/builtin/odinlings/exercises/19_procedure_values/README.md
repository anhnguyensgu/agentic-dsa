# Procedure values

Procedures are values. A procedure type looks like its signature,
`proc(a, b: int) -> int`, so procedures can be stored in variables, struct
fields and arrays, passed as arguments, and written inline as literals.

Odin has no closures: a procedure literal can't use the local variables of
the procedure it's written in. When a callback needs extra data, pass the
data alongside it. Make the data a polymorphic parameter so the callback
stays type-checked, or a `rawptr` when talking to C. Many `core` APIs work
this way (look at `thread.create_and_start_with_poly_data`).

## Further information

- [Procedure type](https://odin-lang.org/docs/overview/#procedure-type)
- [Calling conventions](https://odin-lang.org/docs/overview/#calling-conventions)
- [FAQ: closures](https://odin-lang.org/docs/faq/)
