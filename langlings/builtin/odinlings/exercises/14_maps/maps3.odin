// maps3.odin
//
// Build a table of goals scored and conceded by each team from a list of
// match results.
package main

import "core:testing"

Match :: struct {
	home, away:             string,
	home_goals, away_goals: int,
}

Team :: struct {
	scored, conceded: int,
}

build_scores :: proc(matches: []Match) -> map[string]Team {
	scores := make(map[string]Team)
	for m in matches {
		// TODO: Map values can't be updated in place like this. A team that
		// shows up for the first time starts at zero.
		scores[m.home].scored += m.home_goals
		scores[m.home].conceded += m.away_goals
		scores[m.away].scored += m.away_goals
		scores[m.away].conceded += m.home_goals
	}
	return scores
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

MATCHES :: []Match {
	{"England", "France", 4, 2},
	{"France", "Italy", 3, 1},
	{"Poland", "Spain", 2, 0},
	{"Germany", "England", 2, 1},
	{"England", "Spain", 1, 0},
}

@(test)
test_team_count :: proc(t: ^testing.T) {
	scores := build_scores(MATCHES)
	defer delete(scores)
	testing.expect_value(t, len(scores), 6)
}

@(test)
test_england :: proc(t: ^testing.T) {
	scores := build_scores(MATCHES)
	defer delete(scores)
	testing.expect_value(t, scores["England"], Team{scored = 6, conceded = 4})
}

@(test)
test_spain :: proc(t: ^testing.T) {
	scores := build_scores(MATCHES)
	defer delete(scores)
	testing.expect_value(t, scores["Spain"], Team{scored = 0, conceded = 3})
}
