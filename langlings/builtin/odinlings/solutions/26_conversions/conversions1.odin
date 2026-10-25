// conversions1.odin
package main

import "core:testing"

truncate :: proc(f: f64) -> int {
	return int(f)
}

float_bits :: proc(f: f32) -> u32 {
	// `u32(f)` converts the value 1.0 to 1. `transmute` keeps the bits.
	return transmute(u32)f
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_truncate :: proc(t: ^testing.T) {
	testing.expect_value(t, truncate(2.9), 2)
	testing.expect_value(t, truncate(-2.9), -2)
}

@(test)
test_float_bits :: proc(t: ^testing.T) {
	testing.expect_value(t, float_bits(1.0), 0x3F80_0000)
	testing.expect_value(t, float_bits(-2.0), 0xC000_0000)
}
