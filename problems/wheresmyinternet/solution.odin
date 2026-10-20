package main

// Kattis entry point: read all of stdin, print the answer to stdout.
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

main :: proc() {
	data, _ := os.read_entire_file(os.stdin, context.allocator)
	input := string(data)
	_ = input

	// TODO: solve the problem. Example helpers:
	//   n, _ := strconv.parse_int(strings.trim_space(input))
	//   fmt.println(n * 2)
	fmt.println("change me")
}
