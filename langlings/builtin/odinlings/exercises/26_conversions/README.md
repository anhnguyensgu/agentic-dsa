# Conversions

Odin makes every conversion explicit:

- `T(x)` or `cast(T)x` converts a value: `int(2.9)` is 2 (it truncates toward
  zero), and `f32(n)` turns an int into a float.
- `transmute(T)x` keeps the bits and changes the type. The sizes must match:
  `transmute(u32)f32(1)` is `0x3F80_0000`.
- `distinct` makes a new type with the same representation that doesn't mix
  with the original: `Meters :: distinct f64`. Plain `A :: B` is only an
  alias.
- Text goes through `core:strconv`: `parse_int`, `parse_f64`, `itoa`,
  `write_int`, ...

## Further information

- [Type conversion](https://odin-lang.org/docs/overview/#type-conversion), [cast](https://odin-lang.org/docs/overview/#cast-operator), [transmute](https://odin-lang.org/docs/overview/#transmute-operator)
- [Distinct types](https://odin-lang.org/docs/overview/#distinct-types) and [type aliases](https://odin-lang.org/docs/overview/#type-alias)
- [Implicit type conversions](https://odin-lang.org/docs/overview/#implicit-type-conversions)
- Package docs: [core:strconv](https://pkg.odin-lang.org/core/strconv/)
