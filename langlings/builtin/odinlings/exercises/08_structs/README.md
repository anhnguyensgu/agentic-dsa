# Structs

A struct groups named fields:

```odin
Point :: struct {
	x, y: int,
}
p := Point{1, 2}          // every field, in order
q := Point{y = 5}         // by name; the rest are zero
r: Point                  // all zero
```

Structs are values: assigning one copies it. Odin has no methods. Procedures
that work on a struct take it, or a pointer to it, as a parameter.

`using` on a field promotes that field's members, so `e.x` can mean
`e.pos.x`. When the promoted field is another struct, the outer struct can be
passed wherever the inner one is expected. That's Odin's form of subtyping.

## Further information

- [Structs](https://odin-lang.org/docs/overview/#structs) and [struct literals](https://odin-lang.org/docs/overview/#struct-literals)
- [using with struct fields](https://odin-lang.org/docs/overview/#using-with-struct-fields)
- [Subtype polymorphism](https://odin-lang.org/docs/overview/#subtype-polymorphism)
- Demo file: `struct_type`, `using_statement`
