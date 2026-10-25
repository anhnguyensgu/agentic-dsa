// loops3.odin
//
// `break` leaves the innermost loop. To leave an outer one, label it and name
// the label: `outer: for ... { for ... { break outer } }`.
package main

import "core:testing"

Grid :: [3][3]int

// Find the first cell, row by row, that holds `target`.
find :: proc(grid: Grid, target: int) -> (row, col: int, found: bool) {
	for r in 0 ..< 3 {
		for c in 0 ..< 3 {
			if grid[r][c] == target {
				row, col, found = r, c, true
				// TODO: This only stops the inner loop, so a later match
				// overwrites the first one.
				break
			}
		}
	}
	return
}

main :: proc() {
	// You can optionally experiment here.
}

// Don't change the tests!

@(test)
test_find_first_match :: proc(t: ^testing.T) {
	grid := Grid{
		{1, 2, 7},
		{7, 5, 6},
		{8, 9, 7},
	}
	row, col, found := find(grid, 7)
	testing.expect_value(t, found, true)
	testing.expect_value(t, row, 0)
	testing.expect_value(t, col, 2)
}

@(test)
test_not_found :: proc(t: ^testing.T) {
	_, _, found := find(Grid{}, 7)
	testing.expect_value(t, found, false)
}
