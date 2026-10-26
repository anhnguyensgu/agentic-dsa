// arrays1.odin
package main

import "core:testing"

reset_first :: proc(arr: [3]int) {
	// TODO: Make this zero the first element of the caller's array. The test
	// passes `&nums`; change the parameter to match.
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
	// TODO: What is `a[0]` now?
	testing.expect_value(t, a[0], ???)
}
