// generics4.odin
//
// Both members of this overload group accept anything, so every call is
// ambiguous. `where` clauses can tell them apart.
package main

import "base:intrinsics"
import "core:testing"

// TODO: Only for numeric types.
describe_number :: proc(x: $T) -> string {
	return "number"
}

// TODO: Only for types that aren't numeric.
describe_other :: proc(x: $T) -> string {
	return "something else"
}

describe :: proc {
	describe_number,
	describe_other,
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_describe :: proc(t: ^testing.T) {
	testing.expect_value(t, describe(42), "number")
	testing.expect_value(t, describe(2.5), "number")
	testing.expect_value(t, describe("hi"), "something else")
	testing.expect_value(t, describe(true), "something else")
}
