// maps2.odin
package main

import "core:testing"

Fruit :: enum {
	Apple,
	Banana,
	Mango,
	Lychee,
	Pineapple,
}

fill_basket :: proc(basket: ^map[Fruit]int) {
	for fruit in Fruit {
		// `in` and `not_in` test for a key without reading its value.
		if fruit not_in basket {
			basket[fruit] = 1
		}
	}
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_existing_fruit_untouched :: proc(t: ^testing.T) {
	basket := make(map[Fruit]int)
	defer delete(basket)
	basket[.Apple] = 4
	basket[.Mango] = 2

	fill_basket(&basket)

	testing.expect_value(t, basket[.Apple], 4)
	testing.expect_value(t, basket[.Mango], 2)
}

@(test)
test_every_fruit_present :: proc(t: ^testing.T) {
	basket := make(map[Fruit]int)
	defer delete(basket)
	basket[.Apple] = 4

	fill_basket(&basket)

	testing.expect_value(t, len(basket), len(Fruit))
	testing.expect_value(t, basket[.Lychee], 1)
}
