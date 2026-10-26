// arrays2.odin
//
// Each of these is one short expression. No loops!
package main

import "core:testing"

Vec3 :: [3]f32

midpoint :: proc(a, b: Vec3) -> Vec3 {
	// TODO: Halfway between `a` and `b`.
	return ???
}

flatten :: proc(v: Vec3) -> Vec3 {
	// TODO: The same `x` and `y`, with `z` set to 0. Swizzle fields help.
	return ???
}

reverse :: proc(v: Vec3) -> Vec3 {
	// TODO: [x, y, z] becomes [z, y, x].
	return ???
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

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
