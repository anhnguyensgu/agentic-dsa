// primitives6.odin
package main

import "core:testing"

ring_index :: proc(i, n: int) -> int {
	return i %% n
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
	// 260 doesn't fit in 8 bits, so it wraps: 260 - 256 = 4.
	testing.expect_value(t, a + b, 4)
}
