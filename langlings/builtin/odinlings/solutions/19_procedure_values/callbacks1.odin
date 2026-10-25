// callbacks1.odin
package main

import "core:testing"

Op :: proc(a, b: int) -> int

add :: proc(a, b: int) -> int {
	return a + b
}

mul :: proc(a, b: int) -> int {
	return a * b
}

fold :: proc(xs: []int, start: int, op: Op) -> int {
	acc := start
	for x in xs {
		acc = op(acc, x)
	}
	return acc
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_fold :: proc(t: ^testing.T) {
	xs := []int{1, 2, 3, 4}
	testing.expect_value(t, fold(xs, 0, add), 10)
	testing.expect_value(t, fold(xs, 1, mul), 24)

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
