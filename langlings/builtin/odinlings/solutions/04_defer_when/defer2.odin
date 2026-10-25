// defer2.odin
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

	// 2: recorded inside the block, before its deferred `x = 3` runs.
	// 3: the block has ended, so `x` is 3 now.
	// 0, 10, 1, 11: a loop body is a scope, so its defer runs every iteration.
	// 3: the first defer runs last, with `x` as it is at the end.
	expected := [?]int{2, 3, 0, 10, 1, 11, 3}

	testing.expect_value(t, r.count, len(expected))
	for value, i in expected {
		testing.expect_value(t, r.values[i], value)
	}
}
