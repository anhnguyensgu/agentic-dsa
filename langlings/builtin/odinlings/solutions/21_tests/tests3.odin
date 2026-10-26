// tests3.odin
package main

import "core:testing"

Rectangle :: struct {
	w, h: int,
}

make_rectangle :: proc(w, h: int) -> (Rectangle, bool) {
	// The bug: zero passed the `< 0` check. Zero isn't positive.
	if w <= 0 || h <= 0 {
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
		{-10, 10, false},
		{10, -10, false},
		{0, 10, false},
	}

	testing.expectf(t, len(cases) >= 4, "only %d cases, add the missing ones", len(cases))
	for c in cases {
		_, ok := make_rectangle(c.w, c.h)
		testing.expectf(t, ok == c.ok, "make_rectangle(%d, %d): ok is %v, want %v", c.w, c.h, ok, c.ok)
	}
}
