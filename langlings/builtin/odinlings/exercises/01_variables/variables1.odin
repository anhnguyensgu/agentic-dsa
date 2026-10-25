// variables1.odin
package main

import "core:fmt"

main :: proc() {
	// TODO: `x` was never declared. Declare it here instead of assigning.
	x = 5

	fmt.println("x has the value", x)
}
