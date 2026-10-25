# any, typeid and reflection

Every type has run-time type information. `typeid_of(T)` (or `T` itself
where a `typeid` is expected) identifies a type, and `type_info_of` gives
the details. `size_of`, `align_of` and `offset_of` answer layout questions
at compile time. Struct directives change the layout: `#packed` removes
padding, `#align(N)` sets the alignment, `#raw_union` overlaps the fields.

`any` holds a pointer to a value plus its `typeid`, so it can refer to a
value of any type. Type-switch on it like a union. `fmt.println` takes
`..any`, and that's how it prints anything.

Struct fields can carry tags, `` name: string `json:"user_name"` ``, which
`core:reflect` reads at run time. `core:encoding/json` uses them to name
fields.

## Further information

- [typeid type](https://odin-lang.org/docs/overview/#typeid-type) and [any type](https://odin-lang.org/docs/overview/#any-type)
- [Struct directives](https://odin-lang.org/docs/overview/#struct-directives) and [struct field tags](https://odin-lang.org/docs/overview/#struct-field-tags)
- Package docs: [core:reflect](https://pkg.odin-lang.org/core/reflect/), [core:encoding/json](https://pkg.odin-lang.org/core/encoding/json/)
- Demo file: `reflection`, `union_type`
