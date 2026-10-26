// strings4.odin
//
// `fmt.aprintf` allocates its result with `context.allocator`, so each call
// needs its own `delete`. `fmt.tprintf` uses `context.temp_allocator`
// instead: scratch memory you never free one piece at a time.
package main

import "core:fmt"
import "core:strings"
import "core:testing"

Score :: struct {
	name:   string,
	points: int,
}

// scoreboard({{"Ada", 3}, {"Bo", 5}}) is "Ada: 3, Bo: 5". The caller owns
// the result.
scoreboard :: proc(scores: []Score) -> string {
	parts := make([]string, len(scores))
	defer delete(parts)
	for s, i in scores {
		// TODO: These pieces are only needed until `join` has copied them,
		// and right now every one of them leaks.
		parts[i] = fmt.aprintf("%s: %d", s.name, s.points)
	}
	return strings.join(parts, ", ")
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_scoreboard :: proc(t: ^testing.T) {
	board := scoreboard([]Score{{"Ada", 3}, {"Bo", 5}})
	defer delete(board)
	testing.expect_value(t, board, "Ada: 3, Bo: 5")
}
