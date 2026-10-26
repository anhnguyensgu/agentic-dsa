// threads3.odin
package main

import "core:sync/chan"
import "core:testing"
import "core:thread"

producer :: proc(c: chan.Chan(int), n: int) {
	for i in 1 ..= n {
		chan.send(c, i)
	}
	// Closing is the sender's job: it's the one that knows when it's done.
	chan.close(c)
}

consume_all :: proc(c: chan.Chan(int)) -> int {
	total := 0
	for {
		v, ok := chan.recv(c)
		if !ok {
			break
		}
		total += v
	}
	return total
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_producer_consumer :: proc(t: ^testing.T) {
	c, err := chan.create(chan.Chan(int), 4, context.allocator)
	testing.expect_value(t, err, nil)
	defer chan.destroy(c)

	th := thread.create_and_start_with_poly_data2(c, 100, producer)
	total := consume_all(c)
	thread.destroy(th)

	testing.expect_value(t, total, 5050)
}
