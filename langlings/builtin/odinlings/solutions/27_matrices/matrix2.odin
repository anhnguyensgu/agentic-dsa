// matrix2.odin
package main

import "core:math"
import "core:math/linalg"
import "core:testing"

rotate_z :: proc(v: [3]f32, angle: f32) -> [3]f32 {
	q := linalg.quaternion_angle_axis_f32(angle, {0, 0, 1})
	return linalg.mul(q, v)
}

close_enough :: proc(a, b: [3]f32) -> bool {
	d := a - b
	return abs(d.x) < 1e-5 && abs(d.y) < 1e-5 && abs(d.z) < 1e-5
}

main :: proc() {
	// You can optionally experiment here.
}

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
