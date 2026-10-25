// maps1.odin
package main

import "core:testing"

fruit_basket :: proc() -> map[string]int {
	basket := make(map[string]int)

	// Two bananas are already given for you :)
	basket["banana"] = 2

	// TODO: Put more fruit in the basket. See the test for what's needed.

	return basket
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_at_least_three_kinds_of_fruit :: proc(t: ^testing.T) {
	basket := fruit_basket()
	defer delete(basket)
	testing.expect(t, len(basket) >= 3)
}

@(test)
test_at_least_five_fruits :: proc(t: ^testing.T) {
	basket := fruit_basket()
	defer delete(basket)
	total := 0
	for _, count in basket {
		total += count
	}
	testing.expect(t, total >= 5)
}
