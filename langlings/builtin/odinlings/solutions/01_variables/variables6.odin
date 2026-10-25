// variables6.odin
package main

import "core:fmt"

main :: proc() {
	a, b := 1, 2

	// The right-hand side is evaluated before anything is assigned.
	a, b = b, a

	fmt.printfln("a = %d, b = %d", a, b)
}
