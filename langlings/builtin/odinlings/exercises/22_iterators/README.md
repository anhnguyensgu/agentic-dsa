# Iterators

Odin has no iterator interface. An iterator is a procedure that takes a
pointer to some state and returns the next value plus a final `bool` that
says whether there was one. `for` understands that shape:

```odin
for value in next(&state) { ... }          // until the bool is false
for value, index in next(&state) { ... }   // if it returns more values
```

`core:strings` has allocation-free iterators built this way
(`split_iterator`, `split_lines_iterator`, `fields_iterator`). They consume
the string they're given, so iterate over a copy.

For whole-slice work, `core:slice` has `sort`, `sort_by`, `filter`,
`mapper`, `reduce`, `contains`, `reverse` and more. The ones that build a new
slice take an allocator.

## Further information

- [Range-based for loop](https://odin-lang.org/docs/overview/#range-based-for-loop)
- Package docs: [core:slice](https://pkg.odin-lang.org/core/slice/), [core:strings](https://pkg.odin-lang.org/core/strings/)
- Demo file: `range_statements_with_multiple_return_values`
