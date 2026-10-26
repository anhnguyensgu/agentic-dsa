// when1.odin
package main

import "core:fmt"

DEBUG_MODE :: true

main :: proc() {
	// Only the chosen branch is compiled into the program.
	when DEBUG_MODE {
		fmt.println("debug build")
	} else {
		fmt.println("release build")
	}
}
