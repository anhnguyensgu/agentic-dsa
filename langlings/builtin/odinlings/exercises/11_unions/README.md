# Unions

A union holds exactly one value out of a fixed list of types, or `nil`:

```odin
Shape :: union {
	Circle,
	Rect,
}
```

Find out which one it holds with a type switch, `switch v in shape`, where
`v` has the matching type inside each case. Like enum switches, a type switch
must handle every variant unless it's `#partial`.

`v.(Circle)` asserts that `v` holds a `Circle` and panics if it doesn't. The
two-value form, `c, ok := v.(Circle)`, never panics.

`Maybe(T)` is a union with a single variant: a `T`, or nothing. `m.?`
unwraps it into a value and an `ok`.

`any` works the same way but is open to every type. A union lists its types
up front and stores the value inline.

## Further information

- [Unions](https://odin-lang.org/docs/overview/#unions)
- [Type switch statement](https://odin-lang.org/docs/overview/#type-switch-statement)
- [Maybe(T)](https://odin-lang.org/docs/overview/#maybet)
- Demo file: `union_type`, `union_maybe`
