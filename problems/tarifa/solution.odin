package main

// Kattis: tarifa — leftover megabytes for month N+1.
// We get X MB per month; unused MB roll over. Spent P_i over N months.
// Available in month N+1: X*(N+1) - sum(P_i).

import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"

main :: proc() {
	data, _ := os.read_entire_file(os.stdin, context.allocator)
	lines := strings.split(string(data), "\n")

	x, _ := strconv.parse_int(strings.trim_space(lines[0]))
	n, _ := strconv.parse_int(strings.trim_space(lines[1]))

	spent := 0
	for i := 2; i < 2 + n && i < len(lines); i += 1 {
		p, _ := strconv.parse_int(strings.trim_space(lines[i]))
		spent += p
	}

	fmt.println(x * (n + 1) - spent)
}
