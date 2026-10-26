// variables2.odin
package main

import "core:fmt"

main :: proc() {
	// `10` makes `x` an `int`, and an int can't hold 3.5. Starting from a float
	// literal infers `f64` instead. `x: f64 = 10` works too.
	x := 10.0

	x = 3.5
	fmt.println("x is", x)
}
