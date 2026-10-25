// enums3.odin
package main

import "core:testing"

Command :: enum {
	Move,
	Stop,
	Jump,
	Teleport,
}

energy_cost :: proc(c: Command) -> int {
	switch c {
	case .Move:
		return 1
	case .Stop:
		return 0
	case .Jump:
		return 5
	case .Teleport:
		return 50
	}
	return 0
}

is_movement :: proc(c: Command) -> bool {
	// With `#partial`, missing cases are allowed, so adding another command
	// later won't flag this switch. Use it only where that's what you want.
	#partial switch c {
	case .Move, .Jump, .Teleport:
		return true
	}
	return false
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_energy_cost :: proc(t: ^testing.T) {
	testing.expect_value(t, energy_cost(.Move), 1)
	testing.expect_value(t, energy_cost(.Teleport), 50)
}

@(test)
test_is_movement :: proc(t: ^testing.T) {
	testing.expect(t, is_movement(.Teleport))
	testing.expect(t, !is_movement(.Stop))
}
