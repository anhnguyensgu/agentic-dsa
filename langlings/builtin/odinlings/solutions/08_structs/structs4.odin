// structs4.odin
package main

import "core:testing"

Vec2 :: struct {
	x, y: f32,
}

Entity :: struct {
	name:      string,
	using pos: Vec2,
}

// `using` a struct field makes `Frog` a subtype of `Entity`: a `Frog` (or a
// `^Frog`) can be passed where an `Entity` (or `^Entity`) is expected.
Frog :: struct {
	using entity: Entity,
	jump_height:  f32,
}

describe :: proc(e: Entity) -> string {
	return e.name
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_promoted_fields :: proc(t: ^testing.T) {
	e := Entity{name = "rock", pos = {1, 2}}
	testing.expect_value(t, e.x, 1)
	testing.expect_value(t, e.y, 2)
}

@(test)
test_frog_is_an_entity :: proc(t: ^testing.T) {
	frog: Frog
	frog.name = "Fred"
	frog.x = 3
	frog.jump_height = 0.5

	testing.expect_value(t, describe(frog), "Fred")
	testing.expect_value(t, frog.entity.pos.x, 3)
}
