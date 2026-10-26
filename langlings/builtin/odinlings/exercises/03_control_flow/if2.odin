// if2.odin
//
// An `if` can begin with a short statement, separated from the condition by
// `;`. Variables declared there are visible in every branch of the chain, and
// nowhere else.
package main

import "core:testing"

describe_remainder :: proc(a, b: int) -> string {
	// TODO: `r` doesn't exist. Declare it as `a % b` in the `if` itself.
	if r == 0 {
		return "divisible"
	} else if r == 1 {
		return "off by one"
	} else {
		return "not divisible"
	}
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_describe_remainder :: proc(t: ^testing.T) {
	testing.expect_value(t, describe_remainder(10, 5), "divisible")
	testing.expect_value(t, describe_remainder(11, 5), "off by one")
	testing.expect_value(t, describe_remainder(13, 5), "not divisible")
}
