// procedures1.odin
package main

import "core:fmt"

// Top-level declarations can appear in any order: `main` can call `call_me`
// even though it's declared first.
call_me :: proc() {
	fmt.println("Hellope from call_me!")
}

main :: proc() {
	call_me()
}
