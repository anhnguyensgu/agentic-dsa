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
	switch d {
	case .North:
		return .South
	case .East:
		return .West
	case .South:
		return .North
	case .West:
		return .East
	}
	return d
}

turn_right :: proc(d: Direction) -> Direction {
	return Direction((int(d) + 1) % len(Direction))
}

main :: proc() {
	// You can optionally experiment here.
}

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

	for d in Direction {
		testing.expect_value(t, turn_right(turn_right(turn_right(turn_right(d)))), d)
	}
}
