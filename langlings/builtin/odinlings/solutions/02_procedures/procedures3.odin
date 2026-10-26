// procedures3.odin
package main

import "core:fmt"

// `greeting := "Hellope"` infers the parameter's type from its default, just
// like a variable declaration. `greeting: string = "Hellope"` also works.
greet :: proc(name: string, greeting := "Hellope") {
	fmt.printfln("%s, %s!", greeting, name)
}

main :: proc() {
	greet("Ada")
	greet("Bill", greeting = "Good morning")
}
