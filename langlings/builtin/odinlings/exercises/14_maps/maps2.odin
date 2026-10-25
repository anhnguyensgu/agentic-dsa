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

// Make sure the basket has every kind of fruit, adding one of each kind that's
// missing. Fruit already in the basket stays as it is.
fill_basket :: proc(basket: ^map[Fruit]int) {
	for fruit in Fruit {
		// TODO
	}
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

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
