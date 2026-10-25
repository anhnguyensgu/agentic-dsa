// bitfields1.odin
//
// RGB565 packs a color into 16 bits: 5 bits of blue in the lowest bits, then
// 6 bits of green, then 5 bits of red at the top.
//
//     bit:  15      11 10         5 4       0
//           [  red   ][   green   ][  blue  ]
package main

import "core:testing"

// TODO: Define `Rgb565` as a `bit_field` backed by a `u16`, with `u8` fields
// `b`, `g` and `r` of the right widths. Fields are laid out from the lowest
// bit up, in the order you write them.

pack :: proc(r, g, b: u8) -> u16 {
	c := Rgb565{r = r, g = g, b = b}
	return transmute(u16)c
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

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
