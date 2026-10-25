// primitives5.odin
package main

import "core:testing"

average :: proc(total: int, count: int) -> f64 {
	// `f64(total / count)` would divide as integers first and give 3.0.
	return f64(total) / f64(count)
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_average :: proc(t: ^testing.T) {
	testing.expect_value(t, average(7, 2), 3.5)
	testing.expect_value(t, average(9, 3), 3.0)
}
