// pointers4.odin
//
// A pointer into a slice lets the caller change the element it found, and
// `nil` is a natural "not found".
package main

import "core:testing"

Player :: struct {
	name: string,
	hp:   int,
}

find_player :: proc(players: []Player, name: string) -> ^Player {
	// TODO: Return a pointer to the player called `name`, or nil.
	return nil
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_find_and_heal :: proc(t: ^testing.T) {
	players := []Player{{"Ada", 10}, {"Bo", 3}}

	bo := find_player(players, "Bo")
	testing.expect(t, bo != nil)
	if bo != nil {
		bo.hp = 10
	}
	testing.expect_value(t, players[1].hp, 10)
}

@(test)
test_missing_player :: proc(t: ^testing.T) {
	players := []Player{{"Ada", 10}}
	testing.expect(t, find_player(players, "Zed") == nil)
}
