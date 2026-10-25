// iterators2.odin
//
// The test sets `context.allocator` to a panic allocator, so any allocation
// at all crashes it. `strings.split` allocates the slice it returns.
package main

import "core:mem"
import "core:strconv"
import "core:strings"
import "core:testing"

// sum_csv("1, 2, 3") is 6. Fields that aren't numbers count as 0.
sum_csv :: proc(line: string) -> int {
	// TODO: Walk the fields with `strings.split_iterator` instead, which
	// allocates nothing.
	fields := strings.split(line, ",")
	defer delete(fields)

	total := 0
	for field in fields {
		total += strconv.parse_int(strings.trim_space(field)) or_else 0
	}
	return total
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_sum_csv_without_allocating :: proc(t: ^testing.T) {
	context.allocator = mem.panic_allocator()
	testing.expect_value(t, sum_csv("1, 2, 3"), 6)
	testing.expect_value(t, sum_csv("10,x,5"), 15)
	testing.expect_value(t, sum_csv(""), 0)
}
