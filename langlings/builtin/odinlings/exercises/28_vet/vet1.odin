// vet1.odin
//
// The runner builds this with `-vet`. Fix what it finds; one of the findings
// is why the total is wrong.
package main

import "core:fmt"
import "core:strings"

main :: proc() {
	total := 0
	unused := 42
	for i in 1 ..= 3 {
		total := total + i
		fmt.println("running total", total)
	}
	fmt.println("total:", total)
}
