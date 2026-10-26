// bitfields1.odin
package main

import "core:testing"

Rgb565 :: bit_field u16 {
	b: u8 | 5,
	g: u8 | 6,
	r: u8 | 5,
}

pack :: proc(r, g, b: u8) -> u16 {
	// Values too big for a field are truncated to fit.
	c := Rgb565{r = r, g = g, b = b}
	return transmute(u16)c
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_pack :: proc(t: ^testing.T) {
	testing.expect_value(t, pack(31, 0, 0), 0xF800)
	testing.expect_value(t, pack(0, 63, 0), 0x07E0)
	testing.expect_value(t, pack(0, 0, 31), 0x001F)
}

@(test)
test_unpack :: proc(t: ^testing.T) {
	c := transmute(Rgb565)u16(0x07E0)
	testing.expect_value(t, c.r, 0)
	testing.expect_value(t, c.g, 63)
	testing.expect_value(t, c.b, 0)
}

@(test)
test_size :: proc(t: ^testing.T) {
	testing.expect_value(t, size_of(Rgb565), 2)
}
