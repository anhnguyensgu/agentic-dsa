// when2.odin
//
// The runner builds this file with `-define:GREETING=Hellope`. A constant can
// pick that up with `#config(NAME, default)`, which uses the default when
// nothing is defined on the command line.
package main

import "core:fmt"

// TODO: Use the command-line value, falling back to "Hello" when there isn't
// one.
GREETING :: "Hello"

main :: proc() {
	fmt.println(GREETING, "world")
}
