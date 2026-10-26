// procedures4.odin
//
// This store is having a sale: even prices get 10 off, odd prices get 3 off.
package main

import "core:fmt"

is_even :: proc(n: int) -> bool {
	return n % 2 == 0
}

// TODO: Fix the procedure signature.
sale_price :: proc(price: int) {
	if is_even(price) {
		return price - 10
	}
	return price - 3
}

main :: proc() {
	original := 51
	fmt.println("Your sale price is", sale_price(original))
}
