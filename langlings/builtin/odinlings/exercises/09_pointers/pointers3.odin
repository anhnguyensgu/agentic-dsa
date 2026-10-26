// pointers3.odin
//
// The tests in this course fail on memory leaks, so everything allocated has
// to be freed.
package main

import "core:testing"

Counter :: struct {
	count: int,
}

// TODO: `c` lives in this procedure's stack frame, which is gone once it
// returns. Allocate the counter with `new` instead.
make_counter :: proc(start: int) -> ^Counter {
	c := Counter{start}
	return &c
}

tick :: proc(c: ^Counter) {
	c.count += 1
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_counter :: proc(t: ^testing.T) {
	c := make_counter(5)
	// TODO: Free the counter when the test ends.

	tick(c)
	tick(c)
	testing.expect_value(t, c.count, 7)
}
