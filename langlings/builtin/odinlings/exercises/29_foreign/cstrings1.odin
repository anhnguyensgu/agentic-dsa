// cstrings1.odin
package main

import "core:strings"
import "core:testing"

to_c :: proc(s: string, allocator := context.allocator) -> cstring {
	// TODO: A cstring needs a 0 byte after the text, and `s` doesn't have
	// one. Make a copy that does.
	return cstring(s)
}

from_c :: proc(cs: cstring) -> string {
	// TODO: This direction needs no copy.
	return ???
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_round_trip :: proc(t: ^testing.T) {
	cs := to_c("odin")
	defer delete(cs)

	testing.expect_value(t, len(cs), 4)
	testing.expect_value(t, from_c(cs), "odin")

	bytes := transmute([^]u8)cs
	testing.expect_value(t, bytes[4], 0)
}
