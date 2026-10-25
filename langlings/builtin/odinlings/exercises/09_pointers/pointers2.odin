// pointers2.odin
package main

import "core:testing"

Player :: struct {
	name:  string,
	level: int,
}

// TODO: Parameters are read-only copies. Change the parameter so this levels
// up the caller's player. The tests already pass `&hero`.
level_up :: proc(p: Player) {
	p.level += 1
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_level_up :: proc(t: ^testing.T) {
	hero := Player{"Ada", 1}
	level_up(&hero)
	level_up(&hero)
	testing.expect_value(t, hero.level, 3)
}
