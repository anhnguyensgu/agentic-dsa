// intro2.odin
//
// `fmt` is a package from the `core` collection. Nothing is in scope until it
// is imported, not even printing.
package main

import "core:fmt"

main :: proc() {
	fmt.println("Hellope!")
}
