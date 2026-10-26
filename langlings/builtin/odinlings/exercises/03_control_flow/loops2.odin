// loops2.odin
//
// Range loops: `for x in xs` gives each value, `for x, i in xs` adds the
// index, and over a string `for r in s` gives each rune (Unicode code point),
// decoding the UTF-8 bytes for you.
package main

import "core:testing"

rune_count :: proc(s: string) -> int {
	// TODO: `len` counts bytes, and "é" takes two of them. Count runes with a
	// range loop instead.
	return len(s)
}

sum_at_even_indexes :: proc(xs: []int) -> int {
	// TODO: Add up xs[0], xs[2], xs[4], ... using `for value, index in xs`.
	return 0
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_rune_count :: proc(t: ^testing.T) {
	testing.expect_value(t, rune_count("hello"), 5)
	testing.expect_value(t, rune_count("héllo"), 5)
	testing.expect_value(t, rune_count("世界"), 2)
}

@(test)
test_sum_at_even_indexes :: proc(t: ^testing.T) {
	testing.expect_value(t, sum_at_even_indexes([]int{1, 100, 2, 100, 3}), 6)
	testing.expect_value(t, sum_at_even_indexes([]int{}), 0)
}
