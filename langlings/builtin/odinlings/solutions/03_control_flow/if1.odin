// if1.odin
package main

import "core:testing"

bigger :: proc(a, b: int) -> int {
	if a > b {
		return a
	}
	return b
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_ten_is_bigger_than_eight :: proc(t: ^testing.T) {
	testing.expect_value(t, bigger(10, 8), 10)
}

@(test)
test_fortytwo_is_bigger_than_thirtytwo :: proc(t: ^testing.T) {
	testing.expect_value(t, bigger(32, 42), 42)
}

@(test)
test_equal_numbers :: proc(t: ^testing.T) {
	testing.expect_value(t, bigger(42, 42), 42)
}
