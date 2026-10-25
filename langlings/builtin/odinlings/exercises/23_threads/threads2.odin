// threads2.odin
//
// Eight threads increment one counter. `c.value += 1` is a read, an add and a
// write, and two threads doing that at once can lose an update.
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
		// TODO: Lock `c.mutex` for the update below and unlock it right after.
		???
		c.value += 1
	}
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

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
