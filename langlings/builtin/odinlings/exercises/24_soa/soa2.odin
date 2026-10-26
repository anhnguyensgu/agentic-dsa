// soa2.odin
package main

import "core:slice"
import "core:testing"

Point :: struct {
	x, y: f32,
}

centroid :: proc(xs, ys: []f32) -> Point {
	// TODO: Walk `soa_zip(x = xs, y = ys)`. Each element is a `Point`-like
	// value with `.x` and `.y`. Return the average point.
	return ???
}

x_coords :: proc(points: #soa[]Point) -> []f32 {
	// TODO: The x field is already stored as one contiguous array. Return it
	// with `soa_unzip`, without copying.
	return ???
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_centroid :: proc(t: ^testing.T) {
	c := centroid([]f32{0, 2, 4}, []f32{1, 1, 4})
	testing.expect_value(t, c, Point{2, 2})
}

@(test)
test_x_coords :: proc(t: ^testing.T) {
	pts: #soa[3]Point
	pts[0], pts[1], pts[2] = {1, 2}, {3, 4}, {5, 6}

	xs := x_coords(pts[:])
	testing.expect(t, slice.equal(xs, []f32{1, 3, 5}))

	// A view, not a copy.
	xs[0] = 9
	testing.expect_value(t, pts[0].x, 9)
}
