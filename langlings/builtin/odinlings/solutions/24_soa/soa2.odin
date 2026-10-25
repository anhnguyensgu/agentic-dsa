// soa2.odin
package main

import "core:slice"
import "core:testing"

Point :: struct {
	x, y: f32,
}

centroid :: proc(xs, ys: []f32) -> Point {
	sum: Point
	for p in soa_zip(x = xs, y = ys) {
		sum.x += p.x
		sum.y += p.y
	}
	n := f32(len(xs))
	return {sum.x / n, sum.y / n}
}

x_coords :: proc(points: #soa[]Point) -> []f32 {
	xs, _ := soa_unzip(points)
	return xs
}

main :: proc() {
	// You can optionally experiment here.
}

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

	xs[0] = 9
	testing.expect_value(t, pts[0].x, 9)
}
