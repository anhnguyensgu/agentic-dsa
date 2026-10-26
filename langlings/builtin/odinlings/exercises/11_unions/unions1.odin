// unions1.odin
package main

import "core:testing"

Circle :: struct {
	radius: f64,
}

Rect :: struct {
	w, h: f64,
}

Triangle :: struct {
	base, height: f64,
}

Shape :: union {
	Circle,
	Rect,
	Triangle,
}

area :: proc(s: Shape) -> f64 {
	// Inside each case, `v` has that case's type.
	switch v in s {
	case Circle:
		return 3 * v.radius * v.radius // close enough to pi for this course
	case Rect:
		return v.w * v.h
	// TODO: `Shape` gained `Triangle`. Handle it: half of base times height.
	}
	// A nil Shape matches none of the cases.
	return 0
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_area :: proc(t: ^testing.T) {
	testing.expect_value(t, area(Circle{2}), 12)
	testing.expect_value(t, area(Rect{3, 4}), 12)
	testing.expect_value(t, area(Triangle{6, 4}), 12)
}

@(test)
test_nil_shape :: proc(t: ^testing.T) {
	nothing: Shape
	testing.expect(t, nothing == nil)
	testing.expect_value(t, area(nothing), 0)
}
