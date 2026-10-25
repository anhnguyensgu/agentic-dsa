// memory4.odin
//
// Outside of tests, you set up leak checking yourself. This is the usual
// start of a debug `main`: wrap the default allocator in a tracking
// allocator and look at what's left at the end.
package main

import "core:fmt"
import "core:mem"
import "core:strings"

run :: proc() {
	names := make([dynamic]string)
	append(&names, "ada", "bo")

	upper := strings.to_upper("odin")
	fmt.println(names[:], upper)

	// TODO: `run` leaks two allocations. Fix that so `main` reports none.
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
