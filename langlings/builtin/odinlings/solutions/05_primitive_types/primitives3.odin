// primitives3.odin
package main

import "core:fmt"

main :: proc() {
	// The length is part of the type, and every element starts zeroed.
	// `a: [100]int` says the same thing as a declaration.
	a := [100]int{}

	if len(a) >= 100 {
		fmt.println("Wow, that's a big array!")
	} else {
		fmt.println("Meh, I eat arrays like that for breakfast.")
	}
}
