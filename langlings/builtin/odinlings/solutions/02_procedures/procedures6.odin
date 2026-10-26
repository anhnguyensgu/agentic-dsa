// procedures6.odin
package main

import "core:fmt"

clamp_score :: proc(score: int) -> int {
	// Shadow the parameter with a mutable local copy of the same name.
	score := score
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
