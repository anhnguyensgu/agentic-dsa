// enums4.odin
//
// `[Fruit]int` is an enumerated array: exactly one int per `Fruit`, indexed by
// the enum. Literals name each element, `{.Apple = 3, ...}`, and must cover
// every value unless marked `#partial`.
package main

import "core:testing"

Fruit :: enum {
	Apple,
	Banana,
	Cherry,
}

basket_total :: proc(counts: [Fruit]int) -> int {
	// TODO: Apples cost 3, bananas 2, cherries 5.
	prices := [Fruit]int{???}

	total := 0
	// TODO: Add up count * price for each fruit, with `for count, fruit in counts`.
	return total
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_basket_total :: proc(t: ^testing.T) {
	testing.expect_value(t, basket_total(#partial {.Apple = 2, .Cherry = 1}), 11)
	testing.expect_value(t, basket_total({.Apple = 1, .Banana = 1, .Cherry = 1}), 10)
	testing.expect_value(t, basket_total({}), 0)
}
