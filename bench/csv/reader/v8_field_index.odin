package csvbench

import "base:intrinsics"
import "core:fmt"
import "core:os"

// v8: + two-stage scan. v7 still branches on every separator (which column?
// end of record?) and those branches mispredict. Here stage 1 only writes
// every separator position into an index buffer, branch-free; stage 2 walks
// that buffer 7 entries per record and reads columns 3-5 at fixed offsets.
//
// Each entry is pos<<1 | is_newline, so one OR across a record's entries
// checks that it has exactly 7 fields. Like core:encoding/csv (which takes
// the field count from the first record), a ragged record is an error.

NCOLS :: 7
WINDOW :: 64 << 10 // bytes classified per stage-1 pass; keeps the index buffer in L2

// Appends the positions of the set bits of seps to idx[n^:], tagging newlines.
// Writes in unconditional groups of 8 (garbage past the count is overwritten
// later), so idx needs 8 spare slots.
flatten :: #force_inline proc "contextless" (idx: [^]int, n: ^int, base: int, seps, nl: u64) #no_bounds_check {
	seps := seps
	cnt := int(intrinsics.count_ones(seps))
	out := idx[n^:]
	for i in 0 ..< 8 {
		b := intrinsics.count_trailing_zeros(seps)
		out[i] = (base + int(b)) << 1 | int((nl >> b) & 1)
		seps &= seps - 1
	}
	for i := 8; i < cnt; i += 1 {
		b := intrinsics.count_trailing_zeros(seps)
		out[i] = (base + int(b)) << 1 | int((nl >> b) & 1)
		seps &= seps - 1
	}
	n^ += cnt
}

// structurals, but also returns the newline-outside-quotes mask.
classify :: #force_inline proc "contextless" (b: #simd[64]u8, inside: ^u64) -> (seps, nl: u64) {
	seps = structurals(b, inside)
	nlm := simd_eq_mask(b, NEWLINES)
	return seps, seps & nlm
}

simd_eq_mask :: #force_inline proc "contextless" (b, c: #simd[64]u8) -> u64 {
	return transmute(u64)intrinsics.simd_extract_msbs(intrinsics.simd_lanes_eq(b, c))
}

// Field [start, end) of a record, with surrounding quotes stripped.
field :: #force_inline proc(data: []u8, start, end: int, scratch: ^[dynamic]u8) -> string #no_bounds_check {
	s, e := start, end
	if e - s >= 2 && data[s] == '"' {
		s += 1
		e -= 1
		for i in s ..< e {
			if data[i] == '"' {return unescape(data[s:e], scratch)}
		}
	}
	return string(data[s:e])
}

ragged :: proc() -> ! {
	fmt.eprintln("csv error: record does not have", NCOLS, "fields")
	os.exit(1)
}

// Consumes whole records from idx[:n]; returns how many entries it used.
consume_records :: proc(data: []u8, idx: []int, t: ^Table, header: ^bool, scratch: ^[dynamic]u8, $FAST_HASH: bool) -> int #no_bounds_check {
	r := 0
	for r + NCOLS <= len(idx) {
		p := idx[r:]
		r += NCOLS
		if (p[0] | p[1] | p[2] | p[3] | p[4] | p[5]) & 1 != 0 || p[6] & 1 == 0 {ragged()}
		if header^ {
			header^ = false
			continue
		}
		amount := field(data, (p[3] >> 1) + 1, p[4] >> 1, scratch)
		qty := field(data, (p[4] >> 1) + 1, p[5] >> 1, scratch)
		cs, ce := (p[2] >> 1) + 1, p[3] >> 1
		when FAST_HASH {
			key := data[cs] == '"' && ce - cs >= 2 ? key_from_string(field(data, cs, ce, scratch)) : key_in_buffer(data, cs, ce)
			table_add_key(t, key, parse_cents(amount), parse_uint(qty))
		} else {
			table_add(t, field(data, cs, ce, scratch), parse_cents(amount), parse_uint(qty))
		}
	}
	return r
}

scan_index :: proc(data: []u8, t: ^Table, skip_header: bool, $FAST_HASH: bool) #no_bounds_check {
	idx := make([]int, WINDOW + NCOLS + 16)
	defer delete(idx)
	scratch := make([dynamic]u8, 0, 64)
	defer delete(scratch)
	header := skip_header
	inside: u64 = 0
	n := 0 // entries in idx; fewer than NCOLS carried between windows
	nblocks := len(data) / 64
	for w := 0; w < nblocks; {
		wend := min(nblocks, w + WINDOW / 64)
		for ; w < wend; w += 1 {
			base := w * 64
			// Load into a local first: passing unaligned_load's result straight
			// in as an argument can compile to an aligned load, which faults
			// when a thread's chunk starts mid-block.
			block := intrinsics.unaligned_load((^#simd[64]u8)(&data[base]))
			seps, nl := classify(block, &inside)
			flatten(raw_data(idx), &n, base, seps, nl)
		}
		used := consume_records(data, idx[:n], t, &header, &scratch, FAST_HASH)
		copy(idx[:], idx[used:n])
		n -= used
	}

	tail_at := nblocks * 64
	if tail_at < len(data) {
		tail: [64]u8
		copy(tail[:], data[tail_at:])
		block := intrinsics.unaligned_load((^#simd[64]u8)(&tail))
		seps, nl := classify(block, &inside)
		rest := len(data) - tail_at
		live := u64(1) << uint(rest) - 1
		flatten(raw_data(idx), &n, tail_at, seps & live, nl & live)
	}
	used := consume_records(data, idx[:n], t, &header, &scratch, FAST_HASH)
	copy(idx[:], idx[used:n])
	n -= used
	if n > 0 {
		// Last record has no trailing newline: close it at end of data.
		idx[n] = len(data) << 1 | 1
		n += 1
		if consume_records(data, idx[:n], t, &header, &scratch, FAST_HASH) != n {ragged()}
	} else if len(data) > 0 && data[len(data) - 1] != '\n' {
		ragged() // trailing text with no separators
	}
}

v8_field_index :: proc(path: string) -> Result {
	data := map_file(path)
	defer unmap_file(data)
	t := table_make()
	defer table_destroy(&t)
	scan_index(data, &t, true, FAST_HASH = false)
	return result_from_table(&t)
}
