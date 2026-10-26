// context1.odin
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
		// Callees see the context of the scope they're called from.
		testing.expect_value(t, read_index(), 2)
	}
	// The block's change ended with the block.
	testing.expect_value(t, read_index(), 1)

	// `set_index` changed its own copy, which is gone once it returns.
	set_index(5)
	testing.expect_value(t, read_index(), 1)
}
