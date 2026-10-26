// primitives3.odin
package main

import "core:fmt"

main :: proc() {
	// TODO: Make `a` a fixed array with at least 100 elements.
	a := ???

	if len(a) >= 100 {
		fmt.println("Wow, that's a big array!")
	} else {
		fmt.println("Meh, I eat arrays like that for breakfast.")
	}
}
