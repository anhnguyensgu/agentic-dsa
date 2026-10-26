// when2.odin
package main

import "core:fmt"

GREETING :: #config(GREETING, "Hello")

main :: proc() {
	fmt.println(GREETING, "world")
}
