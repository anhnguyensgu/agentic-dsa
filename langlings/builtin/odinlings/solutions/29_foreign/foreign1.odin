// foreign1.odin
package main

import "core:fmt"

foreign import libc "system:c"

foreign libc {
	strlen :: proc(s: cstring) -> uint ---

	@(link_name = "atoi")
	c_atoi :: proc(s: cstring) -> i32 ---
}

main :: proc() {
	// String literals convert to cstring on their own; the compiler adds the 0.
	fmt.println(strlen("hellope"))
	fmt.println(c_atoi("41") + 1)
}
