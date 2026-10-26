#+vet unused-procedures
// vet3.odin
//
// The tag on the first line makes any procedure that is declared but never
// used a compile error. Keep the tag, and fix the code.
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
		// Members get 10% off every item.
		total += item.cents
	}
	fmt.println("total:", total)
}
