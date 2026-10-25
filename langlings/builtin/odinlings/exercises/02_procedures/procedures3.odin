// procedures3.odin
package main

import "core:fmt"

// TODO: Give `greeting` a default value of "Hellope" so both calls in `main`
// compile. Don't change `main`.
greet :: proc(name: string, greeting: string) {
	fmt.printfln("%s, %s!", greeting, name)
}

main :: proc() {
	greet("Ada")
	greet("Bill", greeting = "Good morning")
}
