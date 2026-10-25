// errors5.odin
package main

import "core:fmt"
import "core:strings"
import "core:testing"

File_Not_Found :: struct {
	path: string,
}

Syntax_Error :: struct {
	line: int,
}

Load_Error :: union {
	File_Not_Found,
	Syntax_Error,
}

Files :: map[string]string

read_file :: proc(files: Files, path: string) -> (string, Load_Error) {
	if text, ok := files[path]; ok {
		return text, nil
	}
	return "", File_Not_Found{path}
}

count_settings :: proc(text: string) -> (int, Load_Error) {
	text := text
	count, line_number := 0, 0
	for line in strings.split_lines_iterator(&text) {
		line_number += 1
		if line == "" {
			continue
		}
		if strings.index_byte(line, '=') < 0 {
			return 0, Syntax_Error{line_number}
		}
		count += 1
	}
	return count, nil
}

load_settings :: proc(files: Files, path: string) -> (count: int, err: Load_Error) {
	text := read_file(files, path) or_return
	return count_settings(text)
}

describe :: proc(err: Load_Error) -> string {
	switch e in err {
	case File_Not_Found:
		return fmt.tprintf("missing file: %s", e.path)
	case Syntax_Error:
		return fmt.tprintf("syntax error on line %d", e.line)
	}
	// A nil union matches no case.
	return "ok"
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_load_settings :: proc(t: ^testing.T) {
	files := make(Files)
	defer delete(files)
	files["good.ini"] = "volume=11\n\ntheme=dark\n"
	files["bad.ini"] = "volume=11\ntheme dark\n"

	count, err := load_settings(files, "good.ini")
	testing.expect_value(t, count, 2)
	testing.expect_value(t, describe(err), "ok")

	_, err = load_settings(files, "bad.ini")
	testing.expect_value(t, describe(err), "syntax error on line 2")

	_, err = load_settings(files, "nope.ini")
	testing.expect_value(t, describe(err), "missing file: nope.ini")
}
