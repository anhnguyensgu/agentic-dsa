// slices1.odin
package main

import "core:testing"

double_all :: proc(xs: []int) {
	// `&x` makes `x` point at the element itself.
	for &x in xs {
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
	// `s[0]` is `a[1]`: the slice starts at index 1 of the same memory.
	testing.expect_value(t, a[1], 50)
}
