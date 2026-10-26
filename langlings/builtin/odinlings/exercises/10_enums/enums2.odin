// enums2.odin
package main

import "core:testing"

Direction :: enum {
	North,
	East,
	South,
	West,
}

opposite :: proc(d: Direction) -> Direction {
	// TODO: Switch on `d`. The cases and results can use the short form,
	// `.North`, since their type is known.
	return d
}

turn_right :: proc(d: Direction) -> Direction {
	// TODO: Do this without a switch. The values are numbered 0 to 3 in
	// order, `int(d)` gives the number, `Direction(n)` turns it back, and
	// `len(Direction)` is 4.
	return d
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_opposite :: proc(t: ^testing.T) {
	testing.expect_value(t, opposite(.North), Direction.South)
	testing.expect_value(t, opposite(.East), Direction.West)
	testing.expect_value(t, opposite(.South), Direction.North)
	testing.expect_value(t, opposite(.West), Direction.East)
}

@(test)
test_turn_right :: proc(t: ^testing.T) {
	testing.expect_value(t, turn_right(.North), Direction.East)
	testing.expect_value(t, turn_right(.West), Direction.North)

	// Turning right four times gets you back where you started.
	for d in Direction {
		testing.expect_value(t, turn_right(turn_right(turn_right(turn_right(d)))), d)
	}
}
