// generics3.odin
package main

import "base:intrinsics"
import "core:testing"

sum :: proc(values: [$N]$T) -> T where intrinsics.type_is_numeric(T) {
	// `T(0)` would work too. Untyped 0 converts to any numeric T.
	total: T = 0
	for v in values {
		total += v
	}
	return total
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_sum :: proc(t: ^testing.T) {
	testing.expect_value(t, sum([3]int{1, 2, 3}), 6)
	testing.expect_value(t, sum([2]f32{0.5, 0.25}), 0.75)
	testing.expect_value(t, sum([5]u8{1, 1, 1, 1, 1}), 5)
}
