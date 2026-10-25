// switch2.odin
package main

import "core:fmt"

launch_from :: proc(stage: int) {
	switch stage {
	case 3:
		fmt.println("fuel")
		fallthrough
	case 2:
		fmt.println("ignition")
		fallthrough
	case 1:
		fmt.println("liftoff")
	}
}

main :: proc() {
	launch_from(3)
}
