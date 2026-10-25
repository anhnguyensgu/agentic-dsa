// variables6.odin
//
// This compiles, but prints the wrong thing. We wanted to swap `a` and `b`.
package main

import "core:fmt"

main :: proc() {
	a, b := 1, 2

	// TODO: Swap the values. Odin can do this in one assignment, no temporary
	// variable needed.
	a = b
	b = a

	fmt.printfln("a = %d, b = %d", a, b)
}
