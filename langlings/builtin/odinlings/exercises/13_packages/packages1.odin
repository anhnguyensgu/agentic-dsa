// packages1.odin
//
// A local variable here has the same name as a package, and the variable
// wins.
package main

import "core:fmt"
// TODO: Give this import another name, and use that name below.
import "core:strings"

main :: proc() {
	// Don't rename this variable.
	strings := []string{"odin", "is", "fun"}

	joined := strings.join(strings, "-", context.temp_allocator)
	fmt.println(joined)
}
