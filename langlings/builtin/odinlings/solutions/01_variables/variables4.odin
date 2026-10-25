// variables4.odin
package main

import "core:fmt"

main :: proc() {
	// `::` makes a compile-time constant. Constants are usually named in
	// SCREAMING_CASE or Ada_Case, but the compiler doesn't care.
	MAX_LIVES :: 3

	lives: [MAX_LIVES]bool
	fmt.println("lives:", len(lives))
}
