// enums1.odin
package main

import "core:fmt"

// TODO: Define a `Message` enum with the values used in `main`.

main :: proc() {
	fmt.println(Message.Resize)
	fmt.println(Message.Move)
	fmt.println(Message.Echo)
	fmt.println(Message.Quit)
}
