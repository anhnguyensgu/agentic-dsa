// callbacks2.odin
//
// A procedure literal can't see the local variables around it. Here the
// callback needs `limit`, so it doesn't compile.
package main

import "core:testing"

count_if :: proc(xs: []int, pred: proc(x: int) -> bool) -> int {
	n := 0
	for x in xs {
		if pred(x) {
			n += 1
		}
	}
	return n
}

count_above :: proc(xs: []int, limit: int) -> int {
	// TODO: Pass `limit` to the callback as data instead. Change `count_if`
	// so it takes the data and hands it to `pred`.
	return count_if(xs, proc(x: int) -> bool {
		return x > limit
	})
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_count_above :: proc(t: ^testing.T) {
	xs := []int{1, 5, 3, 8, 10}
	testing.expect_value(t, count_above(xs, 4), 3)
	testing.expect_value(t, count_above(xs, 100), 0)
}
