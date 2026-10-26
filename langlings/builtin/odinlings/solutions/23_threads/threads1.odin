// threads1.odin
package main

import "core:testing"
import "core:thread"

Job :: struct {
	part:   []int,
	result: int,
}

sum_job :: proc(job: ^Job) {
	for x in job.part {
		job.result += x
	}
}

parallel_sum :: proc(numbers: []int, $N: int) -> int {
	jobs: [N]Job
	threads: [N]^thread.Thread
	size := (len(numbers) + N - 1) / N
	for i in 0 ..< N {
		lo := min(i * size, len(numbers))
		hi := min(lo + size, len(numbers))
		jobs[i].part = numbers[lo:hi]
		threads[i] = thread.create_and_start_with_poly_data(&jobs[i], sum_job)
	}

	// `destroy` joins first, so this one loop both waits and cleans up.
	// `thread.join_multiple(..threads[:])` then a destroy loop says the same
	// thing in two steps.
	for th in threads {
		thread.destroy(th)
	}

	total := 0
	for job in jobs {
		total += job.result
	}
	return total
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_parallel_sum :: proc(t: ^testing.T) {
	numbers: [1000]int
	for &n, i in numbers {
		n = i + 1
	}
	testing.expect_value(t, parallel_sum(numbers[:], 4), 500500)
}
