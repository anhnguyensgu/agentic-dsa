// structs1.odin
package main

import "core:testing"

// TODO: Define `Color` with three `u8` fields: `red`, `green`, `blue`.

// TODO: Define `Point` with two `int` fields: `x` and `y`.

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

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
