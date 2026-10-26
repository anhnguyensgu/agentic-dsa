// arrays2.odin
package main

import "core:testing"

Vec3 :: [3]f32

midpoint :: proc(a, b: Vec3) -> Vec3 {
	// Element-wise add, then scale every element by 0.5.
	return (a + b) * 0.5
}

flatten :: proc(v: Vec3) -> Vec3 {
	return {v.x, v.y, 0}
}

reverse :: proc(v: Vec3) -> Vec3 {
	return v.zyx
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_midpoint :: proc(t: ^testing.T) {
	testing.expect_value(t, midpoint({0, 0, 0}, {2, 4, 6}), Vec3{1, 2, 3})
	testing.expect_value(t, midpoint({-1, 1, 5}, {1, 1, 5}), Vec3{0, 1, 5})
}

@(test)
test_flatten :: proc(t: ^testing.T) {
	testing.expect_value(t, flatten({1, 2, 3}), Vec3{1, 2, 0})
}

@(test)
test_reverse :: proc(t: ^testing.T) {
	testing.expect_value(t, reverse({1, 2, 3}), Vec3{3, 2, 1})
}
