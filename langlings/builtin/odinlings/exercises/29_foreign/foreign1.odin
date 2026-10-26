// foreign1.odin
//
// Calling straight into the C standard library. This one compiles but fails
// to link: read the linker error for the symbol it couldn't find.
package main

import "core:fmt"

foreign import libc "system:c"

foreign libc {
	strlen :: proc(s: cstring) -> uint ---

	// TODO: In C this function is called `atoi`. Keep the Odin name `c_atoi`,
	// and tell the linker the real one.
	c_atoi :: proc(s: cstring) -> i32 ---
}

main :: proc() {
	fmt.println(strlen("hellope"))
	fmt.println(c_atoi("41") + 1)
}
