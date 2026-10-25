// switch2.odin
//
// Coming from C? In Odin a case never runs into the next one by accident. When
// you do want that, you say so with `fallthrough`.
package main

import "core:fmt"

launch_from :: proc(stage: int) {
	switch stage {
	case 3:
		fmt.println("fuel")
	case 2:
		fmt.println("ignition")
	case 1:
		fmt.println("liftoff")
	}
}

main :: proc() {
	// TODO: Starting at stage 3 should run every later stage too. Fix
	// `launch_from`, not this call.
	launch_from(3)
}
