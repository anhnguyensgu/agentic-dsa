// dynamic3.odin
package main

import "core:slice"
import "core:testing"

remove_first_negative :: proc(xs: ^[dynamic]int) -> bool {
	for x, i in xs {
		if x < 0 {
			// TODO: This is quick, but it fills the gap with the last element
			// and changes the order. Keep the order instead.
			unordered_remove(xs, i)
			return true
		}
	}
	return false
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_remove_first_negative :: proc(t: ^testing.T) {
	xs := make([dynamic]int, 0, 8)
	defer delete(xs)
	append(&xs, 1, -2, 3, 4)

	testing.expect(t, remove_first_negative(&xs))
	testing.expect(t, slice.equal(xs[:], []int{1, 3, 4}))
	testing.expect(t, !remove_first_negative(&xs))
}
