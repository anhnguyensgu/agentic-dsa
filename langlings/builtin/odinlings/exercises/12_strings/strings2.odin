// strings2.odin
package main

import "core:strings"
import "core:testing"

// count_up(3) is "1, 2, 3". The caller owns the result.
count_up :: proc(n: int) -> string {
	b := strings.builder_make()
	for i in 1 ..= n {
		// TODO: Write ", " before every number except the first, then the
		// number. Look at `strings.write_string` and `strings.write_int`.
	}
	// The string shares the builder's memory: deleting it frees the builder.
	return strings.to_string(b)
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_count_up :: proc(t: ^testing.T) {
	s := count_up(3)
	defer delete(s)
	testing.expect_value(t, s, "1, 2, 3")
}

@(test)
test_count_up_one :: proc(t: ^testing.T) {
	s := count_up(1)
	defer delete(s)
	testing.expect_value(t, s, "1")
}
