package main

import "core:bufio"
// Kattis entry point: read all of stdin, print the answer to stdout.
import "core:fmt"
import "core:os"
import "core:strings"

main :: proc() {
	scanner: bufio.Scanner
	bufio.scanner_init(&scanner, os.to_reader(os.stdin))
	defer bufio.scanner_destroy(&scanner)

	if !bufio.scanner_scan(&scanner) {
		return
	}
	input := bufio.scanner_text(&scanner)

	string_builder: strings.Builder
	strings.builder_init(&string_builder)
	defer strings.builder_destroy(&string_builder)
	for i in 0 ..< 3 {
		strings.write_string(&string_builder, input)
		if i == 2 {continue}
		strings.write_string(&string_builder, " ")

	}
	result := strings.to_string(string_builder)
	fmt.println(result)
}
