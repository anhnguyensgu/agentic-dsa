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
	// TODO: Fill in the values you expect. `expect_value` shows both sides
	// when they differ, so a wrong guess teaches you something too.
	testing.expect_value(t, power_of_2(0), ???)
	testing.expect_value(t, power_of_2(1), ???)
	testing.expect_value(t, power_of_2(10), ???)
	testing.expect_value(t, power_of_2(63), ???)
}
