// primitives5.odin
//
// Odin never converts one number type to another behind your back, not even
// int to f64.
package main

import "core:testing"

average :: proc(total: int, count: int) -> f64 {
	// TODO: Convert explicitly. Watch out: converting after an integer
	// division is too late.
	return total / count
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_average :: proc(t: ^testing.T) {
	testing.expect_value(t, average(7, 2), 3.5)
	testing.expect_value(t, average(9, 3), 3.0)
}
