// dynamic3.odin
package main

import "core:slice"
import "core:testing"

remove_first_negative :: proc(xs: ^[dynamic]int) -> bool {
	for x, i in xs {
		if x < 0 {
			// Shifts everything after `i` down by one: O(n), order kept.
			ordered_remove(xs, i)
			return true
		}
	}
	return false
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_remove_first_negative :: proc(t: ^testing.T) {
	xs := make([dynamic]int, 0, 8)
	defer delete(xs)
	append(&xs, 1, -2, 3, 4)

	testing.expect(t, remove_first_negative(&xs))
	testing.expect(t, slice.equal(xs[:], []int{1, 3, 4}))
	testing.expect(t, !remove_first_negative(&xs))
}
