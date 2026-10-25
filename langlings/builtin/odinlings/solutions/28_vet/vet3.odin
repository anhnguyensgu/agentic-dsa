#+vet unused-procedures
// vet3.odin
package main

import "core:fmt"

Item :: struct {
	name:  string,
	cents: int,
}

apply_discount :: proc(cents: int) -> int {
	return cents * 90 / 100
}

main :: proc() {
	cart := []Item{{"tea", 400}, {"cake", 600}}
	total := 0
	for item in cart {
		// The unused procedure was the missing discount.
		total += apply_discount(item.cents)
	}
	fmt.println("total:", total)
}
