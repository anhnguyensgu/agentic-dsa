// threads3.odin
//
// A channel hands values from one thread to another. `chan.send` waits when
// the buffer is full, and `chan.recv` waits for a value. Once the channel is
// closed and drained, `recv` returns ok = false.
package main

import "core:sync/chan"
import "core:testing"
import "core:thread"

producer :: proc(c: chan.Chan(int), n: int) {
	for i in 1 ..= n {
		chan.send(c, i)
	}
	// TODO: Tell the consumer nothing more is coming. Without that, the
	// consumer waits forever.
	???
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

// Don't change the tests!

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
