// pointers4.odin
package main

import "core:testing"

Player :: struct {
	name: string,
	hp:   int,
}

find_player :: proc(players: []Player, name: string) -> ^Player {
	// With `for &p`, `p` is the element itself rather than a copy, so `&p`
	// points into the slice. `&players[i]` with an index works too.
	for &p in players {
		if p.name == name {
			return &p
		}
	}
	return nil
}

main :: proc() {
	// You can optionally experiment here.
}

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
