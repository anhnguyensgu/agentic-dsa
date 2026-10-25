// iterators3.odin
package main

import "core:slice"
import "core:testing"

Student :: struct {
	name:  string,
	grade: int,
}

PASS_MARK :: 50

rank :: proc(students: []Student) {
	slice.sort_by(students, proc(a, b: Student) -> bool {
		if a.grade != b.grade {
			return a.grade > b.grade
		}
		return a.name < b.name
	})
}

passing :: proc(students: []Student, allocator := context.allocator) -> []Student {
	// A procedure literal can still use constants like PASS_MARK; only local
	// variables are out of reach.
	return slice.filter(students, proc(s: Student) -> bool {
		return s.grade >= PASS_MARK
	}, allocator)
}

total_grade :: proc(students: []Student) -> int {
	return slice.reduce(students, 0, proc(acc: int, s: Student) -> int {
		return acc + s.grade
	})
}

main :: proc() {
	// You can optionally experiment here.
}

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
