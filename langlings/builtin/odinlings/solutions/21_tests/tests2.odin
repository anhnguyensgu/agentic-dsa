// tests2.odin
package main

import "core:testing"

power_of_2 :: proc(n: u8) -> u64 {
	return 1 << n
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_power_of_2 :: proc(t: ^testing.T) {
	testing.expect_value(t, power_of_2(0), 1)
	testing.expect_value(t, power_of_2(1), 2)
	testing.expect_value(t, power_of_2(10), 1024)
	testing.expect_value(t, power_of_2(63), 1 << 63)
}
