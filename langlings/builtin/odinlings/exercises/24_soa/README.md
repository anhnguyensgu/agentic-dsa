# Structure of arrays (SoA)

An ordinary array of structs stores each element's fields together:
`x y z x y z x y z`. A loop that only reads `x` still pulls every `y` and `z`
through the cache. A structure-of-arrays layout stores each field
contiguously instead (`x x x y y y z z z`), and Odin does that for you with
one keyword:

```odin
ps: #soa[1024]Particle     // fixed
ds: #soa[dynamic]Particle  // dynamic (append_soa / append, delete)
```

You still write `ps[i].x` and `for &p in ps`, and also get whole field
arrays: `ps.x[i]`. `soa_zip(x = xs, y = ys)` views separate slices as one SoA
slice without copying, and `soa_unzip` goes the other way.

## Further information

- [SoA data types](https://odin-lang.org/docs/overview/#soa-data-types)
- [soa_zip and soa_unzip](https://odin-lang.org/docs/overview/#soa_zip-and-soa_unzip)
- Demo file: `soa_struct_layout`
