// when1.odin
//
// `when` is decided while compiling, so it can only look at constants.
package main

import "core:fmt"

// TODO: Fix this declaration so `when` can use it. Keep the `when` below.
debug_mode := true

main :: proc() {
	when debug_mode {
		fmt.println("debug build")
	} else {
		fmt.println("release build")
	}
}
