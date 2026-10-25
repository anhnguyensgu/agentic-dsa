// vet1.odin
package main

import "core:fmt"

main :: proc() {
	total := 0
	for i in 1 ..= 3 {
		// `total := total + i` declared a new `total` each time around the
		// loop, so the outer one never changed. -vet calls that shadowing.
		total += i
		fmt.println("running total", total)
	}
	fmt.println("total:", total)
}
