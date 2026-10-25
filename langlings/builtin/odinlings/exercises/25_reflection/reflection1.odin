// reflection1.odin
package main

import "core:fmt"
import "core:strings"
import "core:testing"

// describe(1, "hi") is "int(1) string(hi)". Uses the temp allocator.
describe :: proc(values: ..any) -> string {
	b := strings.builder_make(context.temp_allocator)
	for v, i in values {
		if i > 0 {
			strings.write_string(&b, " ")
		}
		switch x in v {
		case int:
			fmt.sbprintf(&b, "int(%d)", x)
		case string:
			fmt.sbprintf(&b, "string(%s)", x)
		// TODO: Booleans read like "bool(true)", and anything else is "?".
		}
	}
	return strings.to_string(b)
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_describe :: proc(t: ^testing.T) {
	testing.expect_value(t, describe(1, "hi", true, 2.5), "int(1) string(hi) bool(true) ?")
	testing.expect_value(t, describe(), "")
}
