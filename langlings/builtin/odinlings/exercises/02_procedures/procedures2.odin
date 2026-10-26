// procedures2.odin
package main

import "core:fmt"

// TODO: Odin needs to know the type of every parameter.
call_me :: proc(num) {
	for i in 0 ..< num {
		fmt.println("Ring! Call number", i + 1)
	}
}

main :: proc() {
	call_me(3)
}
