// if3.odin
//
// `a if condition else b` is an expression: it gives you a value, so it can
// sit on the right of `:=` or after `return`. (Odin also accepts the C-style
// `condition ? a : b`.)
package main

import "core:testing"

abs_value :: proc(n: int) -> int {
	// TODO: One expression, no `if` statement.
	return ???
}

parity :: proc(n: int) -> string {
	// TODO: "even" or "odd", again as one expression.
	return ???
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

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
