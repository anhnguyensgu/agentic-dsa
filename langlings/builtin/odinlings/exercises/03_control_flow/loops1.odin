// loops1.odin
//
// `for` is Odin's only loop keyword. It covers C's `for`, `while`, and the
// infinite loop.
package main

import "core:testing"

sum_to :: proc(n: int) -> int {
	total := 0
	// TODO: Fill in the three parts so the loop visits 1, 2, ..., n.
	for i := ???; ???; ??? {
		total += i
	}
	return total
}

collatz_steps :: proc(start: int) -> int {
	n := start
	steps := 0
	// TODO: Keep going while `n` isn't 1. A while loop is `for condition`.
	for ??? {
		n = n / 2 if n % 2 == 0 else 3 * n + 1
		steps += 1
	}
	return steps
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_sum_to :: proc(t: ^testing.T) {
	testing.expect_value(t, sum_to(0), 0)
	testing.expect_value(t, sum_to(1), 1)
	testing.expect_value(t, sum_to(10), 55)
}

@(test)
test_collatz_steps :: proc(t: ^testing.T) {
	testing.expect_value(t, collatz_steps(1), 0)
	testing.expect_value(t, collatz_steps(6), 8)
	testing.expect_value(t, collatz_steps(27), 111)
}
