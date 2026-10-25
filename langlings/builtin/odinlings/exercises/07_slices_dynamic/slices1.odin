// slices1.odin
package main

import "core:testing"

double_all :: proc(xs: []int) {
	// TODO: `x` is a copy of each element, and copies can't be assigned to.
	// Ask the loop for a reference instead.
	for x in xs {
		x *= 2
	}
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_double_all :: proc(t: ^testing.T) {
	a := [4]int{1, 2, 3, 4}
	double_all(a[:])
	testing.expect_value(t, a, [4]int{2, 4, 6, 8})
}

@(test)
test_slices_share_memory :: proc(t: ^testing.T) {
	a := [3]int{1, 2, 3}
	s := a[1:]
	s[0] = 50
	// TODO: What is `a[1]` now?
	testing.expect_value(t, a[1], ???)
}
