// unions3.odin
//
// `Maybe(int)` holds an `int` or `nil`. Return an `int` and it's wrapped for
// you; return `nil` for "nothing".
package main

import "core:testing"

find_index :: proc(xs: []int, target: int) -> Maybe(int) {
	// TODO: The index of the first `target`, or nothing.
	return nil
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_found :: proc(t: ^testing.T) {
	index, ok := find_index([]int{4, 8, 15, 16}, 15).?
	testing.expect(t, ok)
	testing.expect_value(t, index, 2)
}

@(test)
test_found_at_zero :: proc(t: ^testing.T) {
	// Index 0 is a real answer, which is why "not found" can't just be 0.
	index, ok := find_index([]int{4, 8}, 4).?
	testing.expect(t, ok)
	testing.expect_value(t, index, 0)
}

@(test)
test_not_found :: proc(t: ^testing.T) {
	result := find_index([]int{4, 8}, 99)
	testing.expect(t, result == nil)
}
