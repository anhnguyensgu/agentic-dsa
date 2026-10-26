// defer1.odin
package main

import "core:fmt"

main :: proc() {
	// TODO: Make the steps print in order, 1 to 5, by putting `defer` in front
	// of two of these lines. Don't move or change anything else.
	fmt.println("5. close the door")
	fmt.println("1. open the door")
	fmt.println("4. turn off the light")
	fmt.println("2. turn on the light")
	fmt.println("3. read a book")
}
