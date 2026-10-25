// packages2/shapes/shapes.odin
package shapes

Rect :: struct {
	w, h: int,
}

// Top-level declarations are public unless marked otherwise.
area :: proc(r: Rect) -> int {
	return r.w * r.h
}

is_square :: proc(r: Rect) -> bool {
	return same(r.w, r.h)
}

// `@(private)` alone would hide it from other packages but not from other
// files in this one. "file" narrows it further.
@(private = "file")
same :: proc(a, b: int) -> bool {
	return a == b
}
