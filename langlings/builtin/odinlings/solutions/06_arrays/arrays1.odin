// arrays1.odin
package main

import "core:testing"

reset_first :: proc(arr: ^[3]int) {
	// Indexing a pointer to an array dereferences it for you; `arr^[0]` is
	// the long form.
	arr[0] = 0
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_reset_first :: proc(t: ^testing.T) {
	nums := [3]int{7, 8, 9}
	reset_first(&nums)
	testing.expect_value(t, nums, [3]int{0, 8, 9})
}

@(test)
test_arrays_are_copied :: proc(t: ^testing.T) {
	a := [3]int{1, 2, 3}
	b := a
	b[0] = 99
	// `b := a` copied all three elements, so `a` is untouched.
	testing.expect_value(t, a[0], 1)
}
