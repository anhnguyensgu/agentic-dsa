// unions3.odin
package main

import "core:testing"

find_index :: proc(xs: []int, target: int) -> Maybe(int) {
	for x, i in xs {
		if x == target {
			return i
		}
	}
	return nil
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_found :: proc(t: ^testing.T) {
	index, ok := find_index([]int{4, 8, 15, 16}, 15).?
	testing.expect(t, ok)
	testing.expect_value(t, index, 2)
}

@(test)
test_found_at_zero :: proc(t: ^testing.T) {
	index, ok := find_index([]int{4, 8}, 4).?
	testing.expect(t, ok)
	testing.expect_value(t, index, 0)
}

@(test)
test_not_found :: proc(t: ^testing.T) {
	result := find_index([]int{4, 8}, 99)
	testing.expect(t, result == nil)
}
