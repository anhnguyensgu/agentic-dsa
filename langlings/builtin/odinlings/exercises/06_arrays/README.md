# Arrays

A fixed array `[N]T` is a value, like an `int`: assigning or passing one
copies all N elements. To let a procedure change the caller's array, pass a
pointer to it, `^[N]T`. Indexing through the pointer works without an
explicit `^`.

Arrays of numbers support arithmetic element by element (`a + b`, `a * 2`,
`-a`), and arrays of up to four elements have swizzle fields: `v.x`, `v.y`,
`v.z`, `v.w`, and combinations like `v.xy` or `v.zyx`. Odin calls this array
programming; it's what makes `[3]f32` a usable vector type with no library.

## Further information

- [Fixed arrays](https://odin-lang.org/docs/overview/#fixed-arrays)
- [Array programming](https://odin-lang.org/docs/overview/#array-programming)
- Demo file: `array_programming`
