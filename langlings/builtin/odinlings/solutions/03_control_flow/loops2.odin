// loops2.odin
package main

import "core:testing"

rune_count :: proc(s: string) -> int {
	count := 0
	for _ in s {
		count += 1
	}
	return count
}

sum_at_even_indexes :: proc(xs: []int) -> int {
	total := 0
	for x, i in xs {
		if i % 2 == 0 {
			total += x
		}
	}
	return total
}

main :: proc() {
	// You can optionally experiment here.
}

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
