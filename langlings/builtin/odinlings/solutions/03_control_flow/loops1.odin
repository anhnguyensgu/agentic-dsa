// loops1.odin
package main

import "core:testing"

sum_to :: proc(n: int) -> int {
	total := 0
	for i := 1; i <= n; i += 1 {
		total += i
	}
	return total
}

collatz_steps :: proc(start: int) -> int {
	n := start
	steps := 0
	for n != 1 {
		n = n / 2 if n % 2 == 0 else 3 * n + 1
		steps += 1
	}
	return steps
}

main :: proc() {
	// You can optionally experiment here.
}

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
