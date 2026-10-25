// generics4.odin
package main

import "base:intrinsics"
import "core:testing"

describe_number :: proc(x: $T) -> string where intrinsics.type_is_numeric(T) {
	return "number"
}

describe_other :: proc(x: $T) -> string where !intrinsics.type_is_numeric(T) {
	return "something else"
}

describe :: proc {
	describe_number,
	describe_other,
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_describe :: proc(t: ^testing.T) {
	testing.expect_value(t, describe(42), "number")
	testing.expect_value(t, describe(2.5), "number")
	testing.expect_value(t, describe("hi"), "something else")
	testing.expect_value(t, describe(true), "something else")
}
