// enums4.odin
package main

import "core:testing"

Fruit :: enum {
	Apple,
	Banana,
	Cherry,
}

basket_total :: proc(counts: [Fruit]int) -> int {
	prices := [Fruit]int {
		.Apple  = 3,
		.Banana = 2,
		.Cherry = 5,
	}

	total := 0
	for count, fruit in counts {
		total += count * prices[fruit]
	}
	return total
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_basket_total :: proc(t: ^testing.T) {
	testing.expect_value(t, basket_total(#partial {.Apple = 2, .Cherry = 1}), 11)
	testing.expect_value(t, basket_total({.Apple = 1, .Banana = 1, .Cherry = 1}), 10)
	testing.expect_value(t, basket_total({}), 0)
}
