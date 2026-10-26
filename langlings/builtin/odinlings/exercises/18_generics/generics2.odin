// generics2.odin
package main

import "core:testing"

// TODO: Make `Stack` hold any element type, and update the procedures to
// match. The tests use a stack of strings and a stack of ints.
Stack :: struct {
	items: [dynamic]int,
}

stack_push :: proc(s: ^Stack, x: int) {
	append(&s.items, x)
}

stack_pop :: proc(s: ^Stack) -> (int, bool) {
	if len(s.items) == 0 {
		return 0, false
	}
	return pop(&s.items), true
}

stack_destroy :: proc(s: ^Stack) {
	delete(s.items)
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_string_stack :: proc(t: ^testing.T) {
	s: Stack(string)
	defer stack_destroy(&s)

	stack_push(&s, "a")
	stack_push(&s, "b")

	top, ok := stack_pop(&s)
	testing.expect(t, ok)
	testing.expect_value(t, top, "b")
}

@(test)
test_int_stack :: proc(t: ^testing.T) {
	s: Stack(int)
	defer stack_destroy(&s)

	_, ok := stack_pop(&s)
	testing.expect(t, !ok)

	stack_push(&s, 42)
	top, _ := stack_pop(&s)
	testing.expect_value(t, top, 42)
}
