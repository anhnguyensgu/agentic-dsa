// procedures8.odin
package main

import "core:fmt"

add_ints :: proc(a, b: int) -> int {
	return a + b
}

add_vectors :: proc(a, b: [2]f32) -> [2]f32 {
	return a + b
}

// The compiler chooses a member by the argument types at each call.
add :: proc {
	add_ints,
	add_vectors,
}

main :: proc() {
	fmt.println(add(1, 2))
	fmt.println(add([2]f32{1, 2}, [2]f32{3, 4}))
}
