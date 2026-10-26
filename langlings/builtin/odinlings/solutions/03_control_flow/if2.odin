// if2.odin
package main

import "core:testing"

describe_remainder :: proc(a, b: int) -> string {
	if r := a % b; r == 0 {
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

@(test)
test_describe_remainder :: proc(t: ^testing.T) {
	testing.expect_value(t, describe_remainder(10, 5), "divisible")
	testing.expect_value(t, describe_remainder(11, 5), "off by one")
	testing.expect_value(t, describe_remainder(13, 5), "not divisible")
}
