// structs1.odin
package main

import "core:testing"

Color :: struct {
	red, green, blue: u8,
}

Point :: struct {
	x: int,
	y: int,
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_color :: proc(t: ^testing.T) {
	green := Color{0, 255, 0}
	testing.expect_value(t, green.red, 0)
	testing.expect_value(t, green.green, 255)
	testing.expect_value(t, green.blue, 0)
}

@(test)
test_point :: proc(t: ^testing.T) {
	p := Point{x = 3, y = -1}
	testing.expect_value(t, p.x, 3)
	testing.expect_value(t, p.y, -1)

	origin: Point
	testing.expect_value(t, origin, Point{0, 0})
}
