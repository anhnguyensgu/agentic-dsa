// packages2/shapes/shapes.odin
package shapes

Rect :: struct {
	w, h: int,
}

// TODO: `main` needs `area` and `is_square`. Make those two usable from other
// packages, but keep `same` hidden away inside this file.

@(private)
area :: proc(r: Rect) -> int {
	return r.w * r.h
}

@(private)
is_square :: proc(r: Rect) -> bool {
	return same(r.w, r.h)
}

@(private)
same :: proc(a, b: int) -> bool {
	return a == b
}
