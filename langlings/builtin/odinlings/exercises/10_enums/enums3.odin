// enums3.odin
//
// `Teleport` was just added to `Command`. The compiler now points at every
// switch that doesn't know about it.
package main

import "core:testing"

Command :: enum {
	Move,
	Stop,
	Jump,
	Teleport,
}

energy_cost :: proc(c: Command) -> int {
	// TODO: Teleporting costs 50.
	switch c {
	case .Move:
		return 1
	case .Stop:
		return 0
	case .Jump:
		return 5
	}
	return 0
}

is_movement :: proc(c: Command) -> bool {
	// TODO: This switch only cares about some commands, on purpose. Tell the
	// compiler that, rather than adding a case for `.Stop`.
	switch c {
	case .Move, .Jump, .Teleport:
		return true
	}
	return false
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

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
