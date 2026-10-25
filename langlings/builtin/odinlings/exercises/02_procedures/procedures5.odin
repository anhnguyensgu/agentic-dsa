// procedures5.odin
//
// This one is checked by tests instead of by its output. Procedures marked
// `@(test)` run with `odin test`, and `testing.expect_value` fails the test
// when the two values differ.
package main

import "core:testing"

// A procedure can return several values. Named results start at their zero
// value, and a bare `return` returns whatever they hold.
min_max :: proc(numbers: []int) -> (smallest, largest: int) {
	smallest, largest = numbers[0], numbers[0]
	for n in numbers {
		if n < smallest {
			smallest = n
		}
		// TODO: Keep `largest` up to date too.
	}
	return
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_min_max :: proc(t: ^testing.T) {
	lo, hi := min_max([]int{3, 9, -2, 7})
	testing.expect_value(t, lo, -2)
	testing.expect_value(t, hi, 9)
}

@(test)
test_single_element :: proc(t: ^testing.T) {
	lo, hi := min_max([]int{4})
	testing.expect_value(t, lo, 4)
	testing.expect_value(t, hi, 4)
}
