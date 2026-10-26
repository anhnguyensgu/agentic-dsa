// generics1.odin
package main

import "core:testing"

// TODO: This only works for ints. Make it work for any element type.
largest :: proc(xs: []int) -> int {
	best := xs[0]
	for x in xs[1:] {
		if x > best {
			best = x
		}
	}
	return best
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_largest :: proc(t: ^testing.T) {
	testing.expect_value(t, largest([]int{3, 9, 2}), 9)
	testing.expect_value(t, largest([]f64{0.5, -1, 0.25}), 0.5)
	testing.expect_value(t, largest([]string{"apple", "pear", "fig"}), "pear")
}
