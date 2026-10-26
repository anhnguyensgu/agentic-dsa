// packages2/main.odin
//
// You don't need to change this file. The one to fix is shapes/shapes.odin.
package main

import "core:fmt"
// A relative import: the `shapes` directory next to this file.
import "shapes"

main :: proc() {
	r := shapes.Rect{w = 3, h = 4}
	fmt.println("area:", shapes.area(r))
	fmt.println("square:", shapes.is_square(r))
}
