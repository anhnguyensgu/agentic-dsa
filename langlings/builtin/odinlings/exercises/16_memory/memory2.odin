// memory2.odin
//
// Most of `core` lets the caller choose where memory comes from:
//
//     repeat :: proc(s: string, count: int, allocator := context.allocator) -> string
//
// Write your allocating procedures the same way, and pass the allocator on to
// whatever does the allocating.
package main

import "core:strings"
import "core:testing"

// TODO: Add an `allocator` parameter that defaults to `context.allocator`,
// and use it.
shout :: proc(word: string, times: int) -> string {
	upper := strings.to_upper(word, context.temp_allocator)
	return strings.repeat(upper, times)
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_shout_default_allocator :: proc(t: ^testing.T) {
	s := shout("hey", 2)
	defer delete(s)
	testing.expect_value(t, s, "HEYHEY")
}

@(test)
test_shout_temp_allocator :: proc(t: ^testing.T) {
	// Nothing to delete: the temp allocator is cleared in bulk.
	s := shout("ho", 3, context.temp_allocator)
	testing.expect_value(t, s, "HOHOHO")
}
