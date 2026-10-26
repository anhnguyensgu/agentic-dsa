# vet and style checks

Like `clippy` for Rust, the Odin compiler can be stricter than it needs to
be, and these checks catch real bugs as well as style:

- `-vet` turns on unused variables and imports and shadowing (a new variable
  hiding one of the same name), among others.
- `-strict-style` enforces the compiler's own formatting rules: trailing
  commas in multi-line lists, and no unneeded semicolons.
- `#+vet ...` at the top of a file turns checks on for that file only, and
  some checks, like `unused-procedures`, only work that way.

The runner passes these flags for you. The exercises compile without them,
so the bug is only visible once the check is on.

## Further information

- `odin help build`, and look for `-vet` and `-strict-style`
- [Attributes](https://odin-lang.org/docs/overview/#attributes) and [directives](https://odin-lang.org/docs/overview/#directives)
