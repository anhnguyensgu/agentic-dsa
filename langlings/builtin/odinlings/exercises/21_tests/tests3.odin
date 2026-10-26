// tests3.odin
//
// Rectangles must have a positive width and height, but `make_rectangle` has
// a bug. Write the tests first, watch one fail, then fix the procedure.
package main

import "core:testing"

Rectangle :: struct {
	w, h: int,
}

make_rectangle :: proc(w, h: int) -> (Rectangle, bool) {
	if w < 0 || h < 0 {
		return {}, false
	}
	return {w, h}, true
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_make_rectangle :: proc(t: ^testing.T) {
	Case :: struct {
		w, h: int,
		ok:   bool,
	}
	cases := []Case {
		{10, 20, true},
		// TODO: Add cases for a negative width, a negative height, and a
		// width of zero.
	}

	testing.expectf(t, len(cases) >= 4, "only %d cases, add the missing ones", len(cases))
	for c in cases {
		_, ok := make_rectangle(c.w, c.h)
		testing.expectf(t, ok == c.ok, "make_rectangle(%d, %d): ok is %v, want %v", c.w, c.h, ok, c.ok)
	}
}
