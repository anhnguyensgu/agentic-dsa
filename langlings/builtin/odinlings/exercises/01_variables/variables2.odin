// variables2.odin
//
// The type of `x` is inferred from the value it starts with.
package main

import "core:fmt"

main :: proc() {
	// TODO: Change only this line so the assignment below compiles.
	x := 10

	x = 3.5
	fmt.println("x is", x)
}
