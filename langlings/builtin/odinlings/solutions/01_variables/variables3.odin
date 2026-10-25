// variables3.odin
package main

import "core:fmt"

main :: proc() {
	count: int
	price: f64
	name: string
	ready: bool

	// Numbers start at 0, strings are empty, booleans are false. Pointers,
	// maps, slices and unions start as `nil`.
	assert(count == 0)
	assert(price == 0)
	assert(name == "")
	assert(ready == false)

	fmt.println("Zero values checked!")
}
