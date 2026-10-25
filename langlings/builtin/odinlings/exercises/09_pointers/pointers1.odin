// pointers1.odin
package main

import "core:fmt"

main :: proc() {
	score := 10

	// TODO: Make `p` point at `score`.
	p: ^int = ???

	// TODO: Add 5 to `score` through `p`, without writing `score`.
	???

	fmt.println("score is", score)
}
