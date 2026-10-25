// procedures6.odin
//
// Parameters are immutable in Odin: a procedure can't reassign its own
// arguments. That keeps it obvious which values a procedure works on.
package main

import "core:fmt"

clamp_score :: proc(score: int) -> int {
	// TODO: Make this compile by adding one line at the top of the procedure.
	// Keep the rest as it is.
	if score > 100 {
		score = 100
	}
	if score < 0 {
		score = 0
	}
	return score
}

main :: proc() {
	fmt.println(clamp_score(150), clamp_score(-5), clamp_score(42))
}
