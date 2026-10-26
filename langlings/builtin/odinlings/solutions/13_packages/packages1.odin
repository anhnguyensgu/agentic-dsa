// packages1.odin
package main

import "core:fmt"
import str "core:strings"

main :: proc() {
	strings := []string{"odin", "is", "fun"}

	joined := str.join(strings, "-", context.temp_allocator)
	fmt.println(joined)
}
