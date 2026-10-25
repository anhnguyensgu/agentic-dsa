// if3.odin
package main

import "core:testing"

abs_value :: proc(n: int) -> int {
	return -n if n < 0 else n
}

parity :: proc(n: int) -> string {
	return "even" if n % 2 == 0 else "odd"
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_abs_value :: proc(t: ^testing.T) {
	testing.expect_value(t, abs_value(-7), 7)
	testing.expect_value(t, abs_value(7), 7)
	testing.expect_value(t, abs_value(0), 0)
}

@(test)
test_parity :: proc(t: ^testing.T) {
	testing.expect_value(t, parity(4), "even")
	testing.expect_value(t, parity(-3), "odd")
}
