// defer2.odin
//
// Predict the order. Read `run_scopes` carefully: each `defer` belongs to the
// scope it's written in, and it uses the values variables have when it runs.
package main

import "core:testing"

Recorder :: struct {
	values: [8]int,
	count:  int,
}

record :: proc(r: ^Recorder, value: int) {
	r.values[r.count] = value
	r.count += 1
}

run_scopes :: proc(r: ^Recorder) {
	x := 1
	defer record(r, x)
	{
		defer x = 3
		x = 2
		record(r, x)
	}
	record(r, x)
	for i in 0 ..< 2 {
		defer record(r, 10 + i)
		record(r, i)
	}
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_defer_order :: proc(t: ^testing.T) {
	r: Recorder
	run_scopes(&r)

	// TODO: Replace ??? with the values `run_scopes` records, in order.
	expected := [?]int{???}

	testing.expect_value(t, r.count, len(expected))
	for value, i in expected {
		testing.expect_value(t, r.values[i], value)
	}
}
