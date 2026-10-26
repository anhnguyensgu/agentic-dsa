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
	// TODO: Check `is_even` with an even number and with an odd one.
	testing.expect(t, ???)
	testing.expect(t, ???)
}
