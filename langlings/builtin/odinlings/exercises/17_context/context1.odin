// context1.odin
//
// Predict the values. `context.user_index` is a spare int in the context,
// handy for an experiment like this one.
package main

import "core:testing"

read_index :: proc() -> int {
	return context.user_index
}

set_index :: proc(n: int) {
	context.user_index = n
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_context_is_scoped :: proc(t: ^testing.T) {
	context.user_index = 1
	{
		context.user_index = 2
		// TODO: Replace each ??? with the value `read_index` sees.
		testing.expect_value(t, read_index(), ???)
	}
	testing.expect_value(t, read_index(), ???)

	set_index(5)
	testing.expect_value(t, read_index(), ???)
}
