# Threads

`core:thread` starts OS threads. `thread.create_and_start_with_poly_data(data,
fn)` runs `fn(data)` on a new thread, keeping the data's type. Before reading
what a thread produced, wait for it with `thread.join` (or `join_multiple`),
and release it with `thread.destroy`, which also joins.

Two threads must never touch the same memory at the same time when at least
one of them writes. `core:sync` has the tools:

- `sync.Mutex`: lock around the shared data. `sync.guard(&m)` locks it and
  unlocks it at the end of the scope.
- atomics such as `sync.atomic_add` for single counters
- `sync.Wait_Group` to wait for a group of jobs
- `core:sync/chan` channels to pass values from one thread to another

A thread gets a fresh default `context` unless you pass one in
(`init_context`). Watch which allocator a thread uses, since the default
heap allocator is thread-safe but an arena may not be.

## Further information

- Package docs: [core:thread](https://pkg.odin-lang.org/core/thread/), [core:sync](https://pkg.odin-lang.org/core/sync/), [core:sync/chan](https://pkg.odin-lang.org/core/sync/chan/)
- [Deferred procedure associations](https://odin-lang.org/docs/overview/#attributes) (how `sync.guard` unlocks)
- Demo file: `threading_example`, `deferred_procedure_associations`
