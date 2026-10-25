// enums1.odin
package main

import "core:fmt"

Message :: enum {
	Resize,
	Move,
	Echo,
	Quit,
}

main :: proc() {
	fmt.println(Message.Resize)
	fmt.println(Message.Move)
	fmt.println(Message.Echo)
	fmt.println(Message.Quit)
}
