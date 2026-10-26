// procedures4.odin
package main

import "core:fmt"

is_even :: proc(n: int) -> bool {
	return n % 2 == 0
}

sale_price :: proc(price: int) -> int {
	if is_even(price) {
		return price - 10
	}
	return price - 3
}

main :: proc() {
	original := 51
	fmt.println("Your sale price is", sale_price(original))
}
