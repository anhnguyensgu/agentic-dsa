// primitives6.odin
//
// Integers in Odin wrap around when they overflow, and there are two
// remainder operators: `%` takes the sign of the left side, `%%` the sign of
// the right side.
package main

import "core:testing"

// Steps around a ring of `n` slots, like the seats at a round table.
ring_index :: proc(i, n: int) -> int {
	// TODO: ring_index(-1, 5) should be 4, the slot before 0.
	return i % n
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_ring_index :: proc(t: ^testing.T) {
	testing.expect_value(t, ring_index(7, 5), 2)
	testing.expect_value(t, ring_index(-1, 5), 4)
	testing.expect_value(t, ring_index(-6, 5), 4)
}

@(test)
test_wrap_around :: proc(t: ^testing.T) {
	a: u8 = 250
	b: u8 = 10
	// TODO: What does a u8 (0 to 255) hold after 250 + 10?
	testing.expect_value(t, a + b, ???)
}
