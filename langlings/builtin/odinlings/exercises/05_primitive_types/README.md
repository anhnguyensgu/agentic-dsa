# Primitive types

Odin's basic types:

- `bool` (plus sized `b8`, `b16`, ...)
- integers: `int`, `uint`, and sized ones like `i8`, `u8`, `i32`, `u64`
- floats: `f16`, `f32`, `f64`
- `rune`: a Unicode code point, 32 bits; `'A'` is a rune literal
- `string`: UTF-8 bytes plus a length; indexing it gives a `u8`
- fixed arrays `[N]T` and slices `[]T`, which are views into arrays

Odin never converts between these types implicitly. `f64(x)` converts,
`transmute(u32)x` reinterprets the bits. Untyped constants like `1` or `2.5`
are the exception: they fit any type that can hold them exactly.

Integers wrap around on overflow. `%` is the remainder (same sign as the left
side) and `%%` is the modulo (same sign as the right side).

## Further information

- [Basic types](https://odin-lang.org/docs/overview/#basic-types)
- [Type conversion](https://odin-lang.org/docs/overview/#type-conversion) and [untyped types](https://odin-lang.org/docs/overview/#untyped-types)
- [Fixed arrays](https://odin-lang.org/docs/overview/#fixed-arrays) and [slices](https://odin-lang.org/docs/overview/#slices)
- [Arithmetic operators](https://odin-lang.org/docs/overview/#arithmetic-operators) and [integer overflow](https://odin-lang.org/docs/overview/#integer-overflow)
- Demo file: `the_basics`
