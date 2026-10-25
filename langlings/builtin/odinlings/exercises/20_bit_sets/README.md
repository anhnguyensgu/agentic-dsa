# Bit sets and bit fields

`bit_set[E]` is a set of enum values (or of a range like `'a'..='z'`) stored
as the bits of an integer. Operations on it are cheap and read like set math:

```odin
p: Permissions = {.Read, .Write}
.Read in p           // membership; also not_in
p + {.Execute}       // union
p - {.Write}         // difference
p & q                // intersection
p <= q               // subset (and <, >=, > for strict and super-sets)
card(p)              // how many are set
```

A `bit_field` is different: a record whose fields are packed into a backing
integer at exact bit widths, like `r: u8 | 5`. The first field takes the
lowest bits. Use one when bits have a fixed meaning, such as a pixel format, a
hardware register, or a network header. If every field is a 1-bit bool, a
`bit_set` is the better fit.

## Further information

- [Bit sets](https://odin-lang.org/docs/overview/#bit-sets)
- [Bit fields](https://odin-lang.org/docs/overview/#bit-fields)
- Demo file: `bit_set_type`, `bit_field_type`
