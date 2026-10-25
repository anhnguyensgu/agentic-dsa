# Strings

An Odin `string` is a pointer to UTF-8 bytes plus a length. It doesn't own
its bytes, so it behaves like a read-only slice. `len(s)` counts bytes,
`s[i]` is a byte, `s[a:b]` slices by byte offset without copying, and
`for r in s` walks runes.

`core:strings` has the usual tools. Read each procedure's signature to see
whether it allocates:

- `trim_space`, `has_prefix`, `index_byte`, ... return views into the input
  and never allocate.
- `fields`, `split`, `to_upper`, `join`, `concatenate`, ... take an
  `allocator` parameter (default `context.allocator`). The result is yours to
  `delete`.

`strings.Builder` is a growable byte buffer for building a string piece by
piece. `fmt.aprintf` formats into newly allocated memory. `fmt.tprintf`
formats into `context.temp_allocator`, a scratch allocator that is freed all
at once (`free_all(context.temp_allocator)`).

## Further information

- [String type](https://odin-lang.org/docs/overview/#string-type) and [string iteration](https://odin-lang.org/docs/overview/#string-iteration)
- [String formatting and printing](https://odin-lang.org/docs/overview/#string-format-printing)
- [String type conversions](https://odin-lang.org/docs/overview/#string-type-conversions)
- Package docs: [core:strings](https://pkg.odin-lang.org/core/strings/), [core:fmt](https://pkg.odin-lang.org/core/fmt/)
