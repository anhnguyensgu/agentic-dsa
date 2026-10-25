# Memory and allocators

Odin has no garbage collector and no destructors. Memory you allocate with
`make`, `new`, or a `core` procedure that takes an `allocator` stays
allocated until you `delete` or `free` it. That isn't as grim as it sounds:

- Decide who owns each allocation. A procedure that returns allocated memory
  hands it to its caller, and exactly one side frees it.
- Follow the core library convention: a procedure that allocates takes
  `allocator := context.allocator` as its last parameter, so callers pick
  where the memory comes from.
- Group allocations by lifetime. Data that all dies together can go in an
  arena (`core:mem/virtual`) and be freed with one call. Scratch data goes
  in `context.temp_allocator`, freed with `free_all`.
- Check your work with a tracking allocator, `mem.Tracking_Allocator`. The
  test runner uses one, which is why tests in this course fail on leaks and
  bad frees.

## Further information

- [Allocators](https://odin-lang.org/docs/overview/#allocators)
- [Tracking allocator](https://odin-lang.org/docs/overview/#tracking-allocator)
- [Making and deleting slices and dynamic arrays](https://odin-lang.org/docs/overview/#making-and-deleting-slices-and-dynamic-arrays)
- Package docs: [core:mem](https://pkg.odin-lang.org/core/mem/), [core:mem/virtual](https://pkg.odin-lang.org/core/mem/virtual/)
- [Memory allocation strategies](https://www.gingerbill.org/series/memory-allocation-strategies/), by Odin's creator
