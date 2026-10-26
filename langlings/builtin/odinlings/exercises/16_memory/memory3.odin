// memory3.odin
//
// A linked list of a thousand nodes is a thousand allocations, and freeing
// them one by one means walking the whole list. When everything dies at the
// same moment, an arena is simpler: allocate from it, then destroy it once.
package main

import "core:mem/virtual"
import "core:testing"

Node :: struct {
	value: int,
	next:  ^Node,
}

build_list :: proc(n: int, allocator := context.allocator) -> ^Node {
	head: ^Node
	for i := n; i >= 1; i -= 1 {
		node := new(Node, allocator)
		node^ = Node{i, head}
		head = node
	}
	return head
}

sum_list :: proc(head: ^Node) -> int {
	total := 0
	for node := head; node != nil; node = node.next {
		total += node.value
	}
	return total
}

main :: proc() {
	// You can optionally experiment here.
}

// This time the test is yours to change.
@(test)
test_list_in_arena :: proc(t: ^testing.T) {
	arena: virtual.Arena
	// TODO: Set up the arena with `virtual.arena_init_growing`, build the
	// list with `virtual.arena_allocator(&arena)`, and destroy the arena when
	// the test ends with `virtual.arena_destroy`. No per-node frees.

	head := build_list(1000)
	testing.expect_value(t, sum_list(head), 500500)
}
