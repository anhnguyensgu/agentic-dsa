# Enums

```odin
Direction :: enum {
	North,
	East,
	South,
	West,
}
```

Values are numbered from 0 unless you give them numbers, and you can choose
the backing integer type: `enum u8 { ... }`. `fmt` prints an enum by name.

When the expected type is known, write `.North` instead of
`Direction.North`. That's an implicit selector expression.

A `switch` on an enum must handle every value. The compiler tells you when
one is missing, which is handy when you add a new value later. Write
`#partial switch` when you mean to handle only some of them.

An enumerated array `[Direction]int` holds one element per enum value and is
indexed by the enum. Its literals must also list every value, unless marked
`#partial`.

## Further information

- [Enumerations](https://odin-lang.org/docs/overview/#enumerations)
- [Implicit selector expressions](https://odin-lang.org/docs/overview/#implicit-selector-expression)
- [Iterating an enumeration](https://odin-lang.org/docs/overview/#iterating-an-enumeration)
- [Partial switch](https://odin-lang.org/docs/overview/#partial-switch)
- [Enumerated arrays](https://odin-lang.org/docs/overview/#enumerated-array)
- Demo file: `implicit_selector_expression`, `partial_switch`
