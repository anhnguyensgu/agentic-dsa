// reflection2.odin
package main

import "core:testing"

Padded :: struct {
	a: u8,
	b: u32,
	c: u8,
}

Packed :: struct #packed {
	a: u8,
	b: u32,
	c: u8,
}

Reordered :: struct {
	b: u32,
	a: u8,
	c: u8,
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_layout :: proc(t: ^testing.T) {
	testing.expect_value(t, size_of(u16), 2)
	// `a` at 0, then 3 bytes of padding so `b` sits on a multiple of 4.
	testing.expect_value(t, offset_of(Padded, b), 4)
	// a(1) + pad(3) + b(4) + c(1) = 9, rounded up to a multiple of 4.
	testing.expect_value(t, size_of(Padded), 12)
	// No padding at all: 1 + 4 + 1.
	testing.expect_value(t, size_of(Packed), 6)
	// Big fields first leaves less padding: 4 + 1 + 1 = 6, rounded up to 8.
	testing.expect_value(t, size_of(Reordered), 8)
}

@(test)
test_typeids :: proc(t: ^testing.T) {
	x := 3.5
	// An untyped float literal defaults to f64.
	testing.expect_value(t, typeid_of(type_of(x)), f64)
}
