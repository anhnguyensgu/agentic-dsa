// strings4.odin
package main

import "core:fmt"
import "core:strings"
import "core:testing"

Score :: struct {
	name:   string,
	points: int,
}

scoreboard :: proc(scores: []Score) -> string {
	parts := make([]string, len(scores))
	defer delete(parts)
	for s, i in scores {
		// Temporary pieces go in the temp allocator. `join` copies them into
		// one string allocated with `context.allocator`, which the caller
		// deletes. A program frees temp memory in bulk at a point of its
		// choosing, such as the end of a frame; the test runner does it after
		// each test.
		parts[i] = fmt.tprintf("%s: %d", s.name, s.points)
	}
	return strings.join(parts, ", ")
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_scoreboard :: proc(t: ^testing.T) {
	board := scoreboard([]Score{{"Ada", 3}, {"Bo", 5}})
	defer delete(board)
	testing.expect_value(t, board, "Ada: 3, Bo: 5")
}
