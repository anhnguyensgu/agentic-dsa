package main

// Kattis entry point: read all of stdin, print the answer to stdout.
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

main :: proc() {
	data, _ := os.read_entire_file(os.stdin, context.allocator)
	n, ok := strconv.parse_int(strings.trim_space(string(data)))
	if !ok {
		fmt.eprintln("bad input")
		os.exit(1)
	}
	// Alice wins iff the count of stones is odd.
	fmt.println("Alice" if n % 2 == 1 else "Bob")
}
