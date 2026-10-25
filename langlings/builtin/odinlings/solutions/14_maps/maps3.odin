// maps3.odin
package main

import "core:testing"

Match :: struct {
	home, away:             string,
	home_goals, away_goals: int,
}

Team :: struct {
	scored, conceded: int,
}

record :: proc(scores: ^map[string]Team, name: string, scored, conceded: int) {
	// A missing key reads as the zero `Team`, so new teams start at zero.
	team := scores[name]
	team.scored += scored
	team.conceded += conceded
	scores[name] = team
}

build_scores :: proc(matches: []Match) -> map[string]Team {
	scores := make(map[string]Team)
	for m in matches {
		record(&scores, m.home, m.home_goals, m.away_goals)
		record(&scores, m.away, m.away_goals, m.home_goals)
	}
	return scores
}

main :: proc() {
	// You can optionally experiment here.
}

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
