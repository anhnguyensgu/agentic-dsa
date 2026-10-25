# Pointers

`^T` is a pointer to a `T`. `&x` takes the address of `x`, and `p^`
dereferences `p`. Field access and indexing go through pointers on their own,
so `p.level` works on a `^Player`.

Pointers are how a procedure changes something its caller owns, since
parameters are read-only copies. They're also how you refer to memory that
outlives a procedure: `new(T)` allocates a zeroed `T` and returns a `^T`,
which you later release with `free`. A pointer into a procedure's local
variables dies with the procedure, and Odin rejects code that returns one.

`nil` is the zero value of a pointer.

## Further information

- [Pointers](https://odin-lang.org/docs/overview/#pointers)
- [Address operator](https://odin-lang.org/docs/overview/#address-operator)
- [Built-in procedures](https://odin-lang.org/docs/overview/#built-in-procedures): `new`, `free`
- Demo file: `struct_type`
