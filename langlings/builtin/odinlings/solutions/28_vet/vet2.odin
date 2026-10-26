// vet2.odin
package main

import "core:fmt"

// Multi-line lists end with a comma, which keeps diffs to one line when a
// field is added.
Point :: struct {
	x: int,
	y: int,
}

main :: proc() {
	p := Point{3, 4}
	fmt.println(p.x + p.y)
}
