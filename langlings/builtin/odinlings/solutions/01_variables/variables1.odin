// variables1.odin
package main

import "core:fmt"

main :: proc() {
	// `:=` declares and infers the type. `=` only assigns to something that
	// already exists.
	x := 5

	fmt.println("x has the value", x)
}
