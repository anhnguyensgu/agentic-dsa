// callbacks2.odin
package main

import "core:testing"

// The data parameter is polymorphic, so the callback's second parameter is
// checked against whatever the caller passes. Bundle several values in a
// struct when one isn't enough.
count_if :: proc(xs: []int, data: $D, pred: proc(x: int, data: D) -> bool) -> int {
	n := 0
	for x in xs {
		if pred(x, data) {
			n += 1
		}
	}
	return n
}

count_above :: proc(xs: []int, limit: int) -> int {
	return count_if(xs, limit, proc(x: int, limit: int) -> bool {
		return x > limit
	})
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_count_above :: proc(t: ^testing.T) {
	xs := []int{1, 5, 3, 8, 10}
	testing.expect_value(t, count_above(xs, 4), 3)
	testing.expect_value(t, count_above(xs, 100), 0)
}
