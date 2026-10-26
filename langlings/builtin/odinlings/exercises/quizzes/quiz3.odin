// quiz3.odin
//
// Write `parallel_map`: apply `f` to every element of `xs` and return the
// results in the same order, with the work split across `thread_count`
// threads. It has to work for any element and result types, for more threads
// than elements, and for an empty input. The caller owns the result.
//
// Things to remember: a thread runs a procedure plus one piece of data, and
// procedure literals can't capture local variables; each thread should write
// only its own part of the output; and every thread must be waited for and
// destroyed before you return.
package main

import "core:slice"
import "core:testing"
import "core:thread"

parallel_map :: proc(xs: []$T, f: proc(x: T) -> $U, thread_count: int, allocator := context.allocator) -> []U {
	// TODO
	return nil
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_squares :: proc(t: ^testing.T) {
	xs := []int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
	squares := parallel_map(xs, proc(x: int) -> int {
		return x * x
	}, 3)
	defer delete(squares)
	testing.expect(t, slice.equal(squares, []int{1, 4, 9, 16, 25, 36, 49, 64, 81, 100}))
}

@(test)
test_more_threads_than_items :: proc(t: ^testing.T) {
	lengths := parallel_map([]string{"a", "bb", "ccc"}, proc(s: string) -> int {
		return len(s)
	}, 8)
	defer delete(lengths)
	testing.expect(t, slice.equal(lengths, []int{1, 2, 3}))
}

@(test)
test_empty_input :: proc(t: ^testing.T) {
	halves := parallel_map([]int{}, proc(x: int) -> f32 {
		return f32(x) / 2
	}, 4)
	defer delete(halves)
	testing.expect_value(t, len(halves), 0)
}
