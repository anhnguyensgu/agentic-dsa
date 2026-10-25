// pointers2.odin
package main

import "core:testing"

Player :: struct {
	name:  string,
	level: int,
}

// `p.level` reaches through the pointer; no need to write `p^.level`.
level_up :: proc(p: ^Player) {
	p.level += 1
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_level_up :: proc(t: ^testing.T) {
	hero := Player{"Ada", 1}
	level_up(&hero)
	level_up(&hero)
	testing.expect_value(t, hero.level, 3)
}
