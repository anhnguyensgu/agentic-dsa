package csvbench

import "core:os"

// v12: v11 without the quote-counting pass. v10/v11 read the whole file once
// just to count quotes, so each chunk could start at a newline known to be
// outside quotes. v12 guesses instead: each chunk starts after the first
// newline at or after its raw cut, as if that newline were outside quotes.
// That is wrong only when the cut lands in a field holding a quoted newline.
//
// The scan already tracks quote state, so each chunk reports the parity of its
// quotes for free. Chaining those parities from the start of the file gives
// the true quote state at every guessed boundary. A chunk whose start or end
// boundary turns out to be inside quotes is thrown away, and the range up to
// the next good boundary is scanned again. The result is always exact; only
// the rare wrong guess costs extra time.

Spec_Chunk :: struct {
	data:       []u8, // whole file
	start, end: int,
	table:      Table,
	ok:         bool, // every record had NCOLS fields
	odd_quotes: bool, // parity of the quotes in [start, end)
}

// One past the first newline at or after from, ignoring quotes.
next_newline :: proc(data: []u8, from: int) -> int {
	for i in from ..< len(data) {
		if data[i] == '\n' {return i + 1}
	}
	return len(data)
}

v12_speculative :: proc(path: string) -> Result {
	data := map_file(path)
	defer unmap_file(data)
	n := len(data)
	workers := max(1, os.get_processor_core_count())

	chunks := make([]Spec_Chunk, workers)
	defer delete(chunks)
	for &c, k in chunks {
		c.data = data
		c.start = k == 0 ? 0 : next_newline(data, k * n / workers)
	}
	for &c, k in chunks {
		c.end = k + 1 < len(chunks) ? chunks[k + 1].start : n
	}

	run_all(chunks, proc(c: ^Spec_Chunk) {
		c.table = table_make()
		c.ok = true
		if c.start >= c.end {return}
		part := c.data[c.start:c.end]
		c.ok, c.odd_quotes = scan_index(part, &c.table, c.start == 0, Scan_Level.Tuned)
		if !c.ok {c.odd_quotes = count_quotes(part) & 1 == 1} 	// scan stopped early
	})

	// good[k]: chunk k really starts outside quotes. The parity of the quotes
	// before a boundary doesn't depend on where the guesses put the cuts.
	good := make([]bool, workers + 1)
	defer delete(good)
	inside := false
	for c, k in chunks {
		good[k] = !inside
		inside ~= c.odd_quotes
	}
	good[workers] = true

	total := table_make()
	defer table_destroy(&total)
	for k := 0; k < workers; {
		j := k + 1
		for !good[j] {j += 1}
		if j == k + 1 {
			if !chunks[k].ok {ragged()}
			table_merge(&total, &chunks[k].table)
		} else {
			// A guessed cut fell inside a quoted field: redo the range between
			// the two real record boundaries around it.
			t := table_make()
			defer table_destroy(&t)
			scan_index_or_exit(data[chunks[k].start:chunks[j - 1].end], &t, chunks[k].start == 0, Scan_Level.Tuned)
			table_merge(&total, &t)
		}
		k = j
	}
	for &c in chunks {table_destroy(&c.table)}
	return result_from_table(&total)
}
