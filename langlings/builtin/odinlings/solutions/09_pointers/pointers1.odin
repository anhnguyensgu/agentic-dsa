// pointers1.odin
package main

import "core:fmt"

main :: proc() {
	score := 10

	p: ^int = &score

	// The `^` goes after the pointer to dereference it. `p^ = p^ + 5` is the
	// long form.
	p^ += 5

	fmt.println("score is", score)
}
