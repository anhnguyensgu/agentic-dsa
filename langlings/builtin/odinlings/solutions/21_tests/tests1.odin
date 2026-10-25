// tests1.odin
package main

import "core:testing"

is_even :: proc(n: int) -> bool {
	return n % 2 == 0
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_is_even :: proc(t: ^testing.T) {
	testing.expect(t, is_even(10))
	testing.expect(t, !is_even(7))
}
