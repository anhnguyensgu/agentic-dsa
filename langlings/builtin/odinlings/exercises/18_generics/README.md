# Generics (parametric polymorphism)

A `$` in front of a name makes it a compile-time parameter, and the compiler
writes a specialized copy of the procedure for each set of types it's used
with.

```odin
largest :: proc(xs: []$T) -> T       // T is inferred from the argument
make_slice :: proc($T: typeid, n: int) -> []T   // T passed explicitly
sum :: proc(a: [$N]$T) -> T          // N and T both captured from the type
```

Structs can take parameters too, `Stack :: struct($T: typeid) { ... }`, and
procedures accept them as `^Stack($T)`.

A `where` clause limits what a polymorphic procedure accepts, using compile-
time checks from `base:intrinsics` such as `type_is_numeric(T)`. Besides
giving clearer errors, `where` clauses decide which member of an overload
group gets picked.

## Further information

- [Parametric polymorphism](https://odin-lang.org/docs/overview/#parametric-polymorphism)
- [Explicit](https://odin-lang.org/docs/overview/#explicit-parametric-polymorphism) and [implicit](https://odin-lang.org/docs/overview/#implicit-parametric-polymorphism) parametric polymorphism
- [Specialization](https://odin-lang.org/docs/overview/#specialization) and [where clauses](https://odin-lang.org/docs/overview/#where-clauses)
- Demo file: `parametric_polymorphism`, `where_clauses`
