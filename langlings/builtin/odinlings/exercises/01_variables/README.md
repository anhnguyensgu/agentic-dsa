# Variables

`x := 5` declares a new variable and infers its type. `x: int = 5` spells the
type out, and `x: int` declares it with its zero value. `x = 6` assigns to a
variable that already exists.

`::` declares a constant instead: `LIMIT :: 10`. Constants are known at
compile time, so they can be used where Odin needs a compile-time value, like
the length of a fixed array.

Every variable starts zeroed unless you ask otherwise with `---`.

## Further information

- [Variable declarations](https://odin-lang.org/docs/overview/#variable-declarations)
- [Assignment statements](https://odin-lang.org/docs/overview/#assignment-statements)
- [Constant declarations](https://odin-lang.org/docs/overview/#constant-declarations)
- [Zero values](https://odin-lang.org/docs/overview/#zero-values)
- Demo file: `the_basics`
