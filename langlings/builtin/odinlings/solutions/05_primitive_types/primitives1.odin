// primitives1.odin
package main

import "core:fmt"

main :: proc() {
	is_morning := true
	if is_morning {
		fmt.println("Good morning!")
	}

	is_evening := !is_morning

	if is_evening {
		fmt.println("Good evening!")
	} else {
		fmt.println("It's not evening.")
	}
}
