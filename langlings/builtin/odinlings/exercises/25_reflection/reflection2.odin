// reflection2.odin
//
// Predict the layout. Fields are placed in order, each at an offset that's a
// multiple of its own alignment, and a struct's size is rounded up to a
// multiple of its largest field's alignment.
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
	// TODO: Replace each ??? with the number of bytes.
	testing.expect_value(t, size_of(u16), ???)
	testing.expect_value(t, offset_of(Padded, b), ???)
	testing.expect_value(t, size_of(Padded), ???)
	testing.expect_value(t, size_of(Packed), ???)
	testing.expect_value(t, size_of(Reordered), ???)
}

@(test)
test_typeids :: proc(t: ^testing.T) {
	x := 3.5
	// TODO: Which type did `:=` infer for `x`?
	testing.expect_value(t, typeid_of(type_of(x)), ???)
}
