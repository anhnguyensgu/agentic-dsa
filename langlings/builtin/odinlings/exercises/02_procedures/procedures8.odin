// procedures8.odin
//
// Odin never picks between procedures with the same name on its own. If you
// want one name for several procedures, you list them in an overload group.
package main

import "core:fmt"

add_ints :: proc(a, b: int) -> int {
	return a + b
}

add_vectors :: proc(a, b: [2]f32) -> [2]f32 {
	return a + b
}

// TODO: Declare `add` as an explicit overload group of the two procedures above.

main :: proc() {
	fmt.println(add(1, 2))
	fmt.println(add([2]f32{1, 2}, [2]f32{3, 4}))
}
