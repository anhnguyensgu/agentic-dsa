// defer1.odin
package main

import "core:fmt"

main :: proc() {
	// Deferred statements run when `main` ends, last-declared first.
	defer fmt.println("5. close the door")
	fmt.println("1. open the door")
	defer fmt.println("4. turn off the light")
	fmt.println("2. turn on the light")
	fmt.println("3. read a book")
}
