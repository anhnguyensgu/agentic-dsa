// quiz3.odin
package main

import "core:slice"
import "core:testing"
import "core:thread"

parallel_map :: proc(xs: []$T, f: proc(x: T) -> $U, thread_count: int, allocator := context.allocator) -> []U {
	out := make([]U, len(xs), allocator)

	// A local type can use T and U. Each job carries everything its thread
	// needs, since the thread procedure can't reach this procedure's locals.
	Job :: struct {
		input:  []T,
		output: []U,
		f:      proc(x: T) -> U,
	}

	n := max(1, min(thread_count, len(xs)))
	jobs := make([]Job, n, context.temp_allocator)
	threads := make([]^thread.Thread, n, context.temp_allocator)

	size := (len(xs) + n - 1) / n
	for i in 0 ..< n {
		lo := min(i * size, len(xs))
		hi := min(lo + size, len(xs))
		// The output slices don't overlap, so no locking is needed.
		jobs[i] = Job{xs[lo:hi], out[lo:hi], f}
		threads[i] = thread.create_and_start_with_poly_data(&jobs[i], proc(job: ^Job) {
			for x, k in job.input {
				job.output[k] = job.f(x)
			}
		})
	}

	for th in threads {
		thread.destroy(th)
	}
	return out
}

main :: proc() {
	// You can optionally experiment here.
}

@(test)
test_squares :: proc(t: ^testing.T) {
	xs := []int{1, 2, 3, 4, 5, 6, 7, 8, 9, 10}
	squares := parallel_map(xs, proc(x: int) -> int {
		return x * x
	}, 3)
	defer delete(squares)
	testing.expect(t, slice.equal(squares, []int{1, 4, 9, 16, 25, 36, 49, 64, 81, 100}))
}

@(test)
test_more_threads_than_items :: proc(t: ^testing.T) {
	lengths := parallel_map([]string{"a", "bb", "ccc"}, proc(s: string) -> int {
		return len(s)
	}, 8)
	defer delete(lengths)
	testing.expect(t, slice.equal(lengths, []int{1, 2, 3}))
}

@(test)
test_empty_input :: proc(t: ^testing.T) {
	halves := parallel_map([]int{}, proc(x: int) -> f32 {
		return f32(x) / 2
	}, 4)
	defer delete(halves)
	testing.expect_value(t, len(halves), 0)
}
