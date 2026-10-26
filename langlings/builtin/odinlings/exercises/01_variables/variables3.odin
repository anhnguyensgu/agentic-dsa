// variables3.odin
//
// In Odin every variable starts at its type's zero value, so declaring
// without a value is safe. What are those zero values?
package main

import "core:fmt"

main :: proc() {
	count: int
	price: f64
	name: string
	ready: bool

	// TODO: Replace each ??? with the value the variable starts with.
	assert(count == ???)
	assert(price == ???)
	assert(name == ???)
	assert(ready == ???)

	fmt.println("Zero values checked!")
}
