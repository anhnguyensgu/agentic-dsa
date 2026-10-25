// generics2.odin
package main

import "core:testing"

Stack :: struct($T: typeid) {
	items: [dynamic]T,
}

// `^Stack($T)` accepts a pointer to any Stack and names its element type T.
stack_push :: proc(s: ^Stack($T), x: T) {
	append(&s.items, x)
}

stack_pop :: proc(s: ^Stack($T)) -> (T, bool) {
	if len(s.items) == 0 {
		return {}, false
	}
	return pop(&s.items), true
}

stack_destroy :: proc(s: ^Stack($T)) {
	delete(s.items)
}

main :: proc() {
	// You can optionally experiment here.
}

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
