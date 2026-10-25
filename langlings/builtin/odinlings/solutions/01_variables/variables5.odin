// variables5.odin
package main

import "core:fmt"

main :: proc() {
	number := 5
	fmt.println("number is", number)

	// Assign to the existing variable. Declaring `number := ...` again is only
	// allowed inside a new, nested scope `{ ... }`, where it shadows the outer
	// one.
	number = number * 3
	fmt.println("number is", number)
}
