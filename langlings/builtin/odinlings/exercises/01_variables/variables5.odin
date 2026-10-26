// variables5.odin
//
// Odin doesn't let you declare the same name twice in one scope.
package main

import "core:fmt"

main :: proc() {
	number := 5
	fmt.println("number is", number)

	// TODO: Fix this line without renaming the variable.
	number := number * 3
	fmt.println("number is", number)
}
