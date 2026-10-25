// generics1.odin
package main

import "core:testing"

// `$T` declares T the first time it appears; the other uses refer to it.
// Calling this with a type that has no `>` is a compile error, and a `where`
// clause (see generics3) can say so up front.
largest :: proc(xs: []$T) -> T {
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

@(test)
test_largest :: proc(t: ^testing.T) {
	testing.expect_value(t, largest([]int{3, 9, 2}), 9)
	testing.expect_value(t, largest([]f64{0.5, -1, 0.25}), 0.5)
	testing.expect_value(t, largest([]string{"apple", "pear", "fig"}), "pear")
}
