// vet2.odin
//
// The runner builds this with `-strict-style`.
package main

import "core:fmt"

Point :: struct {
	x: int,
	y: int
}

main :: proc() {
	p := Point{3, 4};
	fmt.println(p.x + p.y);
}
