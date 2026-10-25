// variables4.odin
//
// A fixed array's length is part of its type, so it must be known when the
// program is compiled.
package main

import "core:fmt"

main :: proc() {
	// TODO: Make `max_lives` something the compiler can use as an array length.
	max_lives := 3

	lives: [max_lives]bool
	fmt.println("lives:", len(lives))
}
