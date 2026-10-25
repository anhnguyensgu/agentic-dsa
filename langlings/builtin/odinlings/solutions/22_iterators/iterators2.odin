// iterators2.odin
package main

import "core:mem"
import "core:strconv"
import "core:strings"
import "core:testing"

sum_csv :: proc(line: string) -> int {
	// The iterator moves `rest` forward as it goes, so it gets a copy rather
	// than the parameter, which can't be changed anyway.
	rest := line
	total := 0
	for field in strings.split_iterator(&rest, ",") {
		total += strconv.parse_int(strings.trim_space(field)) or_else 0
	}
	return total
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_sum_csv_without_allocating :: proc(t: ^testing.T) {
	context.allocator = mem.panic_allocator()
	testing.expect_value(t, sum_csv("1, 2, 3"), 6)
	testing.expect_value(t, sum_csv("10,x,5"), 15)
	testing.expect_value(t, sum_csv(""), 0)
}
