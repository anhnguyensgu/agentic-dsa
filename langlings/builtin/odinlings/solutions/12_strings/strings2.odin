// strings2.odin
package main

import "core:strings"
import "core:testing"

count_up :: proc(n: int) -> string {
	b := strings.builder_make()
	for i in 1 ..= n {
		if i > 1 {
			strings.write_string(&b, ", ")
		}
		strings.write_int(&b, i)
	}
	return strings.to_string(b)
}

main :: proc() {
	// You can optionally experiment here.
}

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
