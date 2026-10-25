// procedures2.odin
package main

import "core:fmt"

call_me :: proc(num: int) {
	for i in 0 ..< num {
		fmt.println("Ring! Call number", i + 1)
	}
}

main :: proc() {
	call_me(3)
}
