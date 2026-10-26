// generics3.odin
//
// `$N` inside an array type captures the array's length as a compile-time
// constant: `proc(a: [$N]$T)` accepts a fixed array of any length and any
// element type.
package main

import "base:intrinsics"
import "core:testing"

// TODO: Accept a fixed array of any length and any numeric element type. Add
// a `where` clause that only allows numeric `T`.
sum :: proc(values: [4]int) -> int {
	total := 0
	for v in values {
		total += v
	}
	return total
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_sum :: proc(t: ^testing.T) {
	testing.expect_value(t, sum([3]int{1, 2, 3}), 6)
	testing.expect_value(t, sum([2]f32{0.5, 0.25}), 0.75)
	testing.expect_value(t, sum([5]u8{1, 1, 1, 1, 1}), 5)
}
