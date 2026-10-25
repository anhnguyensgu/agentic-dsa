// dynamic2.odin
//
// Appending can change a dynamic array's length, capacity, and where its
// elements live. A procedure that appends to the caller's array needs a
// pointer to it.
package main

import "core:testing"

// TODO: Fix the parameter, and then the `append` call to match.
add_item :: proc(list: [dynamic]string, item: string) {
	append(&list, item)
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_add_item :: proc(t: ^testing.T) {
	list: [dynamic]string
	defer delete(list)

	add_item(&list, "milk")
	add_item(&list, "eggs")

	testing.expect_value(t, len(list), 2)
	testing.expect_value(t, list[1], "eggs")
}
