// dynamic2.odin
package main

import "core:testing"

// `list` is already a pointer here, so it's passed to `append` as it is.
add_item :: proc(list: ^[dynamic]string, item: string) {
	append(list, item)
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_add_item :: proc(t: ^testing.T) {
	list: [dynamic]string
	defer delete(list)

	add_item(&list, "milk")
	add_item(&list, "eggs")

	testing.expect_value(t, len(list), 2)
	testing.expect_value(t, list[1], "eggs")
}
