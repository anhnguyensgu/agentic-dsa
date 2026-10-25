// context3.odin
//
// `messy_library_proc` stands in for code you don't control. It allocates with
// `context.allocator` and never frees, so the test fails with a leak.
package main

import "core:testing"

// Don't change this procedure.
messy_library_proc :: proc() -> int {
	scratch := make([]int, 100)
	for &x, i in scratch {
		x = i * i
	}
	return scratch[99]
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_contain_the_mess :: proc(t: ^testing.T) {
	// TODO: Make the library allocate from the temp allocator instead, just
	// for this call, without changing `messy_library_proc`.
	result := messy_library_proc()

	testing.expect_value(t, result, 9801)
}
