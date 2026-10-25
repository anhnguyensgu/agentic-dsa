# Slices and dynamic arrays

A slice `[]T` is a pointer and a length. It looks into memory that belongs to
something else, such as a fixed array, and owns nothing itself. Writing
through a slice changes that memory.

A dynamic array `[dynamic]T` owns its memory. It has a length, a capacity,
and the allocator it grows with. `append(&arr, x)` adds to it (it takes a
pointer because it may move the elements somewhere bigger), `delete(arr)`
frees it, and `arr[:]` views it as a slice. Remove elements with
`ordered_remove` (keeps the order, shifts the rest down) or
`unordered_remove` (fast, moves the last element into the hole), and take the
last one off with `pop`.

`[dynamic; N]T` is a fixed-capacity dynamic array. It stores up to N elements
inline, needs no allocator, and has nothing to delete.

Range loops give copies. Write `for &x in xs` to get a reference you can
assign through.

## Further information

- [Slices](https://odin-lang.org/docs/overview/#slices)
- [Dynamic arrays](https://odin-lang.org/docs/overview/#dynamic-arrays), [appending](https://odin-lang.org/docs/overview/#appending-to-a-dynamic-array), [removing](https://odin-lang.org/docs/overview/#removing-from-a-dynamic-array)
- [Fixed-capacity dynamic arrays](https://odin-lang.org/docs/overview/#dynamic-nt-fixed-capacity-dynamic-array)
- [Iterating by value or by reference](https://odin-lang.org/docs/overview/#iterating-through-slices-of-structs-by-value-or-by-reference)
- Demo file: `control_flow` (range loops)
