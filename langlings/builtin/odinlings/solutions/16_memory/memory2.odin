// memory2.odin
package main

import "core:strings"
import "core:testing"

// `upper` is scratch: it's only needed until `repeat` has copied it, so it
// goes in the temp allocator whatever the caller picked.
shout :: proc(word: string, times: int, allocator := context.allocator) -> string {
	upper := strings.to_upper(word, context.temp_allocator)
	return strings.repeat(upper, times, allocator)
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_shout_default_allocator :: proc(t: ^testing.T) {
	s := shout("hey", 2)
	defer delete(s)
	testing.expect_value(t, s, "HEYHEY")
}

@(test)
test_shout_temp_allocator :: proc(t: ^testing.T) {
	s := shout("ho", 3, context.temp_allocator)
	testing.expect_value(t, s, "HOHOHO")
}
