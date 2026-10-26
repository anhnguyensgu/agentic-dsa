// cstrings1.odin
package main

import "core:strings"
import "core:testing"

to_c :: proc(s: string, allocator := context.allocator) -> cstring {
	return strings.clone_to_cstring(s, allocator)
}

from_c :: proc(cs: cstring) -> string {
	// Finds the 0 to get the length, then views the same bytes.
	return string(cs)
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_round_trip :: proc(t: ^testing.T) {
	cs := to_c("odin")
	defer delete(cs)

	testing.expect_value(t, len(cs), 4)
	testing.expect_value(t, from_c(cs), "odin")

	bytes := transmute([^]u8)cs
	testing.expect_value(t, bytes[4], 0)
}
