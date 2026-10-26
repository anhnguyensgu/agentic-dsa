// threads2.odin
package main

import "core:sync"
import "core:testing"
import "core:thread"

Counter :: struct {
	mutex: sync.Mutex,
	value: int,
}

increment_many :: proc(c: ^Counter, times: int) {
	for _ in 0 ..< times {
		// `guard` locks now and, through `@(deferred_in)`, unlocks when this
		// scope (the loop body) ends. The long form is
		// `sync.mutex_lock(&c.mutex); defer sync.mutex_unlock(&c.mutex)`.
		// For a lone counter, `sync.atomic_add(&c.value, 1)` needs no mutex.
		sync.guard(&c.mutex)
		c.value += 1
	}
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_no_lost_updates :: proc(t: ^testing.T) {
	counter: Counter
	threads: [8]^thread.Thread
	for &th in threads {
		th = thread.create_and_start_with_poly_data2(&counter, 10_000, increment_many)
	}
	for th in threads {
		thread.destroy(th)
	}
	testing.expect_value(t, counter.value, 80_000)
}
