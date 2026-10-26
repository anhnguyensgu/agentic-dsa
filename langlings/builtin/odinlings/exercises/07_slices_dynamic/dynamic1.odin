// dynamic1.odin
package main

import "core:slice"
import "core:testing"

// Returns 1, 4, 9, ..., n*n. The caller owns the result and must delete it.
squares :: proc(n: int) -> [dynamic]int {
	result: [dynamic]int
	for i in 1 ..= n {
		// TODO: Add `i * i` to the end of `result`.
	}
	return result
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_squares :: proc(t: ^testing.T) {
	s := squares(4)
	defer delete(s)
	testing.expect(t, slice.equal(s[:], []int{1, 4, 9, 16}))
}

@(test)
test_no_squares :: proc(t: ^testing.T) {
	s := squares(0)
	defer delete(s)
	testing.expect_value(t, len(s), 0)
}
