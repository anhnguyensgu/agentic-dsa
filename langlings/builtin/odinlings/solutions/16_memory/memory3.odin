// memory3.odin
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

@(test)
test_list_in_arena :: proc(t: ^testing.T) {
	arena: virtual.Arena
	err := virtual.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer virtual.arena_destroy(&arena)

	head := build_list(1000, virtual.arena_allocator(&arena))
	testing.expect_value(t, sum_list(head), 500500)
}
