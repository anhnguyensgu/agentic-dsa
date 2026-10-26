# C strings and the foreign system

Odin calls C directly. `foreign import` names a library and a `foreign`
block declares its procedures, with `---` in place of a body:

```odin
foreign import libc "system:c"

foreign libc {
	strlen :: proc(s: cstring) -> uint ---
}
```

Declarations in a foreign block use the C calling convention. Attributes
adjust the details: `@(link_name = "...")` when the Odin name differs from
the C symbol, and `@(link_prefix = "...")` on the block for libraries whose
names all share a prefix. `core:c` has the C types (`c.int`, `c.size_t`),
and `core:c/libc` already wraps the C standard library.

A `cstring` is a pointer to bytes ending in a 0. An Odin `string` carries a
length instead, and usually has no 0 after it, so converting a `string` to a
`cstring` needs a copy (`strings.clone_to_cstring`). Going from `cstring` to
`string` is a cheap view.

## Further information

- [Foreign system](https://odin-lang.org/docs/overview/#foreign-system)
- [cstring type](https://odin-lang.org/docs/overview/#cstring-type) and [string conversions](https://odin-lang.org/docs/overview/#string-type-conversions)
- [Using a vendor library](https://odin-lang.org/docs/overview/#using-a-vendor-library)
- Demo file: `foreign_system`, `cstring_example`
