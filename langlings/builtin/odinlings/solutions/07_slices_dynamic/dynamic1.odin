// dynamic1.odin
package main

import "core:slice"
import "core:testing"

squares :: proc(n: int) -> [dynamic]int {
	// Knowing the size up front, `make([dynamic]int, 0, n)` would allocate
	// once instead of growing as it goes.
	result: [dynamic]int
	for i in 1 ..= n {
		append(&result, i * i)
	}
	return result
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_squares :: proc(t: ^testing.T) {
	s := squares(4)
	defer delete(s)
	testing.expect(t, slice.equal(s[:], []int{1, 4, 9, 16}))
}

@(test)
test_no_squares :: proc(t: ^testing.T) {
	s := squares(0)
	defer delete(s)
	testing.expect_value(t, len(s), 0)
}
