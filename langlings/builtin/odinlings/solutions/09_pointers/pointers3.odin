// pointers3.odin
package main

import "core:testing"

Counter :: struct {
	count: int,
}

make_counter :: proc(start: int) -> ^Counter {
	// `new` allocates with `context.allocator` and zeroes the memory.
	c := new(Counter)
	c.count = start
	return c
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
	defer free(c)

	tick(c)
	tick(c)
	testing.expect_value(t, c.count, 7)
}
