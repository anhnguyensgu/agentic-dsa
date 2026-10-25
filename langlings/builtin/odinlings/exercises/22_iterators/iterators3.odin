// iterators3.odin
//
// `core:slice` covers the usual whole-slice operations. Each one takes a
// procedure, and since there are no closures, the procedure gets only the
// elements.
package main

import "core:slice"
import "core:testing"

Student :: struct {
	name:  string,
	grade: int,
}

PASS_MARK :: 50

// Highest grade first; equal grades in alphabetical order.
rank :: proc(students: []Student) {
	// TODO: `slice.sort_by(students, less)`, where `less(a, b)` says
	// whether `a` belongs before `b`.
}

// The students with at least PASS_MARK, in their original order. The caller
// owns the result.
passing :: proc(students: []Student, allocator := context.allocator) -> []Student {
	// TODO: `slice.filter`
	return nil
}

total_grade :: proc(students: []Student) -> int {
	// TODO: `slice.reduce`
	return 0
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

class :: proc() -> [4]Student {
	return {{"Cy", 72}, {"Ada", 91}, {"Bo", 45}, {"Al", 72}}
}

@(test)
test_rank :: proc(t: ^testing.T) {
	students := class()
	rank(students[:])
	want := [4]Student{{"Ada", 91}, {"Al", 72}, {"Cy", 72}, {"Bo", 45}}
	testing.expect_value(t, students, want)
}

@(test)
test_passing :: proc(t: ^testing.T) {
	students := class()
	passed := passing(students[:])
	defer delete(passed)
	testing.expect(t, slice.equal(passed, []Student{{"Cy", 72}, {"Ada", 91}, {"Al", 72}}))
}

@(test)
test_total_grade :: proc(t: ^testing.T) {
	students := class()
	testing.expect_value(t, total_grade(students[:]), 280)
}
