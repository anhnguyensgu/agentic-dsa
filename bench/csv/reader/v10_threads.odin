package csvbench

import "base:intrinsics"
import "core:os"
import "core:simd"
import "core:thread"

// v10: + split the mapped file across threads, one table each, merged at the end.
//
// A chunk cannot start at an arbitrary newline: a quoted field may contain one.
// So first every thread counts the quotes in its raw slice of the file (in
// parallel); the running parity tells whether each raw cut point is inside
// quotes, and each chunk then starts after the first newline outside quotes.
// This stays correct for any RFC 4180 input, at the cost of one extra fast pass.

Chunk :: struct {
	data:      []u8, // whole file
	lo, hi:    int, // raw byte range, used for quote counting
	quotes:    int,
	start, end: int, // record-aligned range this thread aggregates
	table:     Table,
	tuned:     bool, // v11's kernel instead of v9's
}

count_quotes :: proc(data: []u8) -> int #no_bounds_check {
	n := len(data)
	total := 0
	i := 0
	for ; i + 64 <= n; i += 64 {
		b := intrinsics.unaligned_load((^#simd[64]u8)(&data[i]))
		total += intrinsics.count_ones(int(transmute(u64)simd.extract_msbs(simd.lanes_eq(b, QUOTES))))
	}
	for ; i < n; i += 1 {
		if data[i] == '"' {total += 1}
	}
	return total
}

// First record start strictly after `from`, given whether `from` is inside quotes.
next_record_start :: proc(data: []u8, from: int, inside: bool) -> int {
	inside := inside
	for i in from ..< len(data) {
		switch data[i] {
		case '"':  inside = !inside
		case '\n': if !inside {return i + 1}
		}
	}
	return len(data)
}

v10_threads :: proc(path: string) -> Result {
	return scan_threaded(path, tuned = false)
}

scan_threaded :: proc(path: string, tuned: bool) -> Result {
	data := map_file(path)
	defer unmap_file(data)
	n := len(data)
	workers := max(1, os.get_processor_core_count())

	chunks := make([]Chunk, workers)
	defer delete(chunks)
	for &c, k in chunks {
		c.data = data
		c.tuned = tuned
		c.lo = k * n / workers
		c.hi = (k + 1) * n / workers
	}

	run_all(chunks, proc(c: ^Chunk) {c.quotes = count_quotes(c.data[c.lo:c.hi])})

	parity := 0
	for &c, k in chunks {
		c.start = k == 0 ? 0 : next_record_start(data, c.lo, parity & 1 == 1)
		parity += c.quotes
	}
	for &c, k in chunks {
		c.end = k + 1 < len(chunks) ? chunks[k + 1].start : n
	}

	run_all(chunks, proc(c: ^Chunk) {
		c.table = table_make()
		if c.start >= c.end {return}
		if c.tuned {
			scan_index_or_exit(c.data[c.start:c.end], &c.table, c.start == 0, Scan_Level.Tuned)
		} else {
			scan_index_or_exit(c.data[c.start:c.end], &c.table, c.start == 0, Scan_Level.Fast_Hash)
		}
	})

	total := table_make()
	defer table_destroy(&total)
	for &c in chunks {
		table_merge(&total, &c.table)
		table_destroy(&c.table)
	}
	return result_from_table(&total)
}

run_all :: proc(chunks: []$T, fn: proc(c: ^T)) {
	threads := make([]^thread.Thread, len(chunks))
	defer delete(threads)
	for &c, k in chunks {
		threads[k] = thread.create_and_start_with_poly_data(&c, fn, context)
	}
	for t in threads {
		thread.join(t)
		thread.destroy(t)
	}
}
