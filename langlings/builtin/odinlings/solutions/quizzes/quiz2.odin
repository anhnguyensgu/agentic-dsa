// quiz2.odin
package main

import "core:strconv"
import "core:strings"
import "core:testing"

Missing_Colon :: struct {
	line: int,
}

Bad_Score :: struct {
	line: int,
}

Duplicate_Name :: struct {
	name: string,
}

Parse_Error :: union {
	Missing_Colon,
	Bad_Score,
	Duplicate_Name,
}

parse_line :: proc(line: string, line_number: int) -> (name: string, score: int, err: Parse_Error) {
	colon := strings.index_byte(line, ':')
	if colon < 0 {
		return "", 0, Missing_Colon{line_number}
	}
	ok: bool
	score, ok = strconv.parse_int(strings.trim_space(line[colon + 1:]))
	if !ok {
		return "", 0, Bad_Score{line_number}
	}
	name = strings.trim_space(line[:colon])
	return
}

parse_scores :: proc(text: string, allocator := context.allocator) -> (scores: map[string]int, err: Parse_Error) {
	scores = make(map[string]int, allocator = allocator)
	// Cleaning up in a `defer` is tempting, but a defer can't change what is
	// returned: by the time it runs, the results have been copied out. So the
	// parsing goes in a helper, and the cleanup happens here, in plain sight.
	if err = fill_scores(&scores, text); err != nil {
		delete(scores)
		return nil, err
	}
	return
}

fill_scores :: proc(scores: ^map[string]int, text: string) -> Parse_Error {
	text := text
	line_number := 0
	for line in strings.split_lines_iterator(&text) {
		line_number += 1
		if strings.trim_space(line) == "" {
			continue
		}
		name, score := parse_line(line, line_number) or_return
		if name in scores {
			return Duplicate_Name{name}
		}
		scores[name] = score
	}
	return nil
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_valid_scoreboard :: proc(t: ^testing.T) {
	scores, err := parse_scores("ada: 12\n\n  bo :7\n")
	defer delete(scores)
	testing.expect_value(t, err, nil)
	testing.expect_value(t, len(scores), 2)
	testing.expect_value(t, scores["ada"], 12)
	testing.expect_value(t, scores["bo"], 7)
}

@(test)
test_missing_colon :: proc(t: ^testing.T) {
	scores, err := parse_scores("ada: 12\nbo 7\n")
	testing.expect_value(t, err, Parse_Error(Missing_Colon{line = 2}))
	testing.expect(t, scores == nil)
}

@(test)
test_bad_score :: proc(t: ^testing.T) {
	scores, err := parse_scores("ada: twelve")
	testing.expect_value(t, err, Parse_Error(Bad_Score{line = 1}))
	testing.expect(t, scores == nil)
}

@(test)
test_duplicate_name :: proc(t: ^testing.T) {
	scores, err := parse_scores("ada: 1\nbo: 2\nada: 3")
	testing.expect_value(t, err, Parse_Error(Duplicate_Name{name = "ada"}))
	testing.expect(t, scores == nil)
}
