// quiz2.odin
//
// Parse a scoreboard like this into a map from name to score:
//
//     ada: 12
//     bo: 7
//
// - Blank lines are skipped, and spaces around names and scores don't matter.
// - A line without ':' is a `Missing_Colon`, a score that isn't a number is a
//   `Bad_Score` (both with the 1-based line number), and a name that appears
//   twice is a `Duplicate_Name`.
// - On success the caller owns the map. On error, nothing may leak and the
//   returned map is nil; the tests check both.
//
// The map's keys can be views into `text`, so only the map itself needs
// freeing.
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
	// TODO
	return
}

parse_scores :: proc(text: string, allocator := context.allocator) -> (scores: map[string]int, err: Parse_Error) {
	// TODO
	return
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

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
