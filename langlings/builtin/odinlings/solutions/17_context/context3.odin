// context3.odin
package main

import "core:testing"

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
	result: int
	{
		// Only calls made inside this block see the temp allocator. In a real
		// program you'd `free_all(context.temp_allocator)` at a convenient
		// point; the test runner does it after each test.
		context.allocator = context.temp_allocator
		result = messy_library_proc()
	}

	testing.expect_value(t, result, 9801)
}
