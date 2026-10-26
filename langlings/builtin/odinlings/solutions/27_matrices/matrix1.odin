// matrix1.odin
package main

import "base:intrinsics"
import "core:testing"

rotate90 :: proc(v: [2]f32) -> [2]f32 {
	m := matrix[2, 2]f32{
		0, -1,
		1, 0,
	}
	return m * v
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_rotate90 :: proc(t: ^testing.T) {
	testing.expect_value(t, rotate90({1, 0}), [2]f32{0, 1})
	testing.expect_value(t, rotate90({0, 1}), [2]f32{-1, 0})
	testing.expect_value(t, rotate90(rotate90({3, 4})), [2]f32{-3, -4})
}

@(test)
test_transpose :: proc(t: ^testing.T) {
	m := matrix[2, 3]f32{
		1, 2, 3,
		4, 5, 6,
	}
	mt := intrinsics.transpose(m)
	// `mt` is a matrix[3, 2]: row 0 of the transpose is column 0 of `m`.
	testing.expect_value(t, mt[0, 1], 4)
	testing.expect_value(t, size_of(mt) / size_of(f32), 6)
}
