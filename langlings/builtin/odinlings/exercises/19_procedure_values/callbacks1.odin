// callbacks1.odin
package main

import "core:testing"

Op :: proc(a, b: int) -> int

add :: proc(a, b: int) -> int {
	return a + b
}

// TODO: Declare `mul`, an `Op` that multiplies.

// Combine the elements left to right: fold({1, 2, 3}, 0, add) is
// ((0 + 1) + 2) + 3.
fold :: proc(xs: []int, start: int, op: Op) -> int {
	// TODO
	return start
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_fold :: proc(t: ^testing.T) {
	xs := []int{1, 2, 3, 4}
	testing.expect_value(t, fold(xs, 0, add), 10)
	testing.expect_value(t, fold(xs, 1, mul), 24)

	// A procedure literal works anywhere a procedure value does.
	biggest := fold(xs, 0, proc(a, b: int) -> int {
		return max(a, b)
	})
	testing.expect_value(t, biggest, 4)
}

@(test)
test_ops_table :: proc(t: ^testing.T) {
	ops := [2]Op{add, mul}
	testing.expect_value(t, ops[1](6, 7), 42)
}
