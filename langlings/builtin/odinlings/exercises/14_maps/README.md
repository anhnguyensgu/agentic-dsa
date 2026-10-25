# Maps

`map[K]V` is a hash map. Create one with `make(map[string]int)` (or let the
zero value allocate on the first insert) and free it with `delete`.

```odin
m["apple"] = 3             // insert or overwrite
n := m["apple"]            // zero value if the key is missing
n, ok := m["apple"]        // ok says whether it was there
if "apple" in m { ... }    // also `not_in`
delete_key(&m, "apple")
for key, value in m { ... }
```

Map values can't be changed in place: `m["a"].count += 1` doesn't compile.
Read the value, change it, and store it back, or get a pointer with
`if p, ok := &m["a"]; ok { p.count += 1 }`.

A procedure that inserts into the caller's map takes a pointer, `^map[K]V`,
since inserting may reallocate. Iteration order is not defined.

## Further information

- [Maps](https://odin-lang.org/docs/overview/#maps)
- [Map container calls](https://odin-lang.org/docs/overview/#map-container-calls)
- Demo file: `map_type`
