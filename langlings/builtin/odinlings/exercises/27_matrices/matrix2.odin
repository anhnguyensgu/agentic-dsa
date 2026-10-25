// matrix2.odin
package main

import "core:math"
import "core:math/linalg"
import "core:testing"

// Rotate `v` by `angle` radians around the z axis.
rotate_z :: proc(v: [3]f32, angle: f32) -> [3]f32 {
	// TODO: Build the rotation with `linalg.quaternion_angle_axis_f32`, then
	// apply it with `linalg.mul(q, v)`.
	return v
}

close_enough :: proc(a, b: [3]f32) -> bool {
	d := a - b
	return abs(d.x) < 1e-5 && abs(d.y) < 1e-5 && abs(d.z) < 1e-5
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_quarter_turn :: proc(t: ^testing.T) {
	got := rotate_z({1, 0, 0}, math.PI / 2)
	testing.expectf(t, close_enough(got, {0, 1, 0}), "got %v", got)
}

@(test)
test_half_turn :: proc(t: ^testing.T) {
	got := rotate_z({1, 2, 3}, math.PI)
	testing.expectf(t, close_enough(got, {-1, -2, 3}), "got %v", got)
}
