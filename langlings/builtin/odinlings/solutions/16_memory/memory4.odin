// memory4.odin
package main

import "core:fmt"
import "core:mem"
import "core:strings"

run :: proc() {
	names := make([dynamic]string)
	defer delete(names)
	append(&names, "ada", "bo")

	upper := strings.to_upper("odin")
	defer delete(upper)
	fmt.println(names[:], upper)
}

main :: proc() {
	track: mem.Tracking_Allocator
	mem.tracking_allocator_init(&track, context.allocator)
	defer mem.tracking_allocator_destroy(&track)
	context.allocator = mem.tracking_allocator(&track)

	run()

	for _, entry in track.allocation_map {
		fmt.printfln("leaked %v bytes at %v", entry.size, entry.location)
	}
	fmt.println("leaks:", len(track.allocation_map))
	fmt.println("bad frees:", len(track.bad_free_array))
}
