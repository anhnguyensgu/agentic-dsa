package csvbench

import "base:intrinsics"
import "core:fmt"
import "core:os"
import "core:simd"
import "core:strings"
import "core:sys/posix"

// v6: classify 64 bytes at a time instead of one. For each block we build
// bitmasks of quotes, commas and newlines, turn the quote mask into an
// "inside quotes" mask with a prefix XOR, and keep only the commas/newlines
// outside quotes. Each set bit is a field boundary; we jump between them with
// count_trailing_zeros, never looking at the bytes in between.
//
// Escaped quotes ("") toggle the mask twice, so they need no special case.

QUOTES: #simd[64]u8 : '"'
COMMAS: #simd[64]u8 : ','
NEWLINES: #simd[64]u8 : '\n'

// Bit i of the result is set when byte i is a comma or newline outside quotes.
// `inside` carries the quote state across blocks: all ones or all zeros.
structurals :: #force_inline proc "contextless" (b: #simd[64]u8, inside: ^u64) -> u64 {
	q := transmute(u64)simd.extract_msbs(simd.lanes_eq(b, QUOTES))
	c := transmute(u64)simd.extract_msbs(simd.lanes_eq(b, COMMAS))
	nl := transmute(u64)simd.extract_msbs(simd.lanes_eq(b, NEWLINES))
	// Prefix XOR: bit i = parity of quotes at positions <= i.
	q ~= q << 1
	q ~= q << 2
	q ~= q << 4
	q ~= q << 8
	q ~= q << 16
	q ~= q << 32
	q ~= inside^
	inside^ = u64(i64(q) >> 63)
	return (c | nl) & ~q
}

Simd_State :: struct {
	data:            []u8,
	t:               ^Table,
	scratch:         [dynamic]u8,
	field_start:     int,
	col:             int,
	header:          bool,
	city, amount, qty: string,
}

// The field [field_start, end) is complete.
end_field :: #force_inline proc(st: ^Simd_State, end: int) #no_bounds_check {
	if st.col < COL_CITY || st.col > COL_QTY {return}
	s, e := st.field_start, end
	escaped := false
	if e - s >= 2 && st.data[s] == '"' {
		s += 1
		e -= 1
		if st.col == COL_CITY {
			for i in s ..< e {if st.data[i] == '"' {escaped = true; break}}
		}
	}
	switch st.col {
	case COL_CITY:   st.city = escaped ? unescape(st.data[s:e], &st.scratch) : string(st.data[s:e])
	case COL_AMOUNT: st.amount = string(st.data[s:e])
	case COL_QTY:    st.qty = string(st.data[s:e])
	}
}

end_record :: #force_inline proc(st: ^Simd_State) {
	if st.header {
		st.header = false
	} else {
		table_add(st.t, st.city, parse_cents(st.amount), parse_uint(st.qty))
	}
	st.col = 0
}

emit :: #force_inline proc(st: ^Simd_State, seps: u64, base: int) #no_bounds_check {
	seps := seps
	for seps != 0 {
		p := base + int(intrinsics.count_trailing_zeros(seps))
		seps &= seps - 1
		end_field(st, p)
		st.field_start = p + 1
		if st.data[p] == '\n' {
			end_record(st)
		} else {
			st.col += 1
		}
	}
}

// Scans whole records in data. Never reads past len(data), so data may be a
// memory-mapped file or a slice of one.
scan_simd :: proc(data: []u8, t: ^Table, skip_header: bool) #no_bounds_check {
	st := Simd_State {
		data    = data,
		t       = t,
		header  = skip_header,
		scratch = make([dynamic]u8, 0, 64),
	}
	defer delete(st.scratch)
	n := len(data)
	inside: u64 = 0
	i := 0
	for ; i + 64 <= n; i += 64 {
		block := intrinsics.unaligned_load((^#simd[64]u8)(&data[i]))
		emit(&st, structurals(block, &inside), i)
	}
	if i < n {
		tail: [64]u8
		copy(tail[:], data[i:])
		block := intrinsics.unaligned_load((^#simd[64]u8)(&tail))
		emit(&st, structurals(block, &inside) & (u64(1) << uint(n - i) - 1), i)
	}
	if st.field_start < n || st.col > 0 { 	// last record has no trailing newline
		end_field(&st, n)
		end_record(&st)
	}
}

// Benchmark floor: classification only, no field handling.
count_separators :: proc(data: []u8) -> int #no_bounds_check {
	inside: u64 = 0
	total := 0
	i := 0
	for ; i + 64 <= len(data); i += 64 {
		block := intrinsics.unaligned_load((^#simd[64]u8)(&data[i]))
		total += intrinsics.count_ones(int(structurals(block, &inside)))
	}
	return total
}

v6_simd :: proc(path: string) -> Result {
	data := read_file(path)
	defer delete(data)
	t := table_make()
	defer table_destroy(&t)
	scan_simd(data, &t, true)
	return result_from_table(&t)
}

// v7: + mmap the file instead of reading it into a heap buffer. Skips the
// copy out of the page cache and the page faults on a fresh 1 GB allocation.
v7_mmap :: proc(path: string) -> Result {
	data := map_file(path)
	defer unmap_file(data)
	t := table_make()
	defer table_destroy(&t)
	scan_simd(data, &t, true)
	return result_from_table(&t)
}

map_file :: proc(path: string) -> []u8 {
	fd := posix.open(strings.clone_to_cstring(path, context.temp_allocator), {})
	if fd < 0 {
		fmt.eprintln("cannot open", path, posix.strerror())
		os.exit(1)
	}
	defer posix.close(fd)
	st: posix.stat_t
	if posix.fstat(fd, &st) != .OK {
		fmt.eprintln("cannot stat", path, posix.strerror())
		os.exit(1)
	}
	size := int(st.st_size)
	if size == 0 {return nil}
	p := posix.mmap(nil, uint(size), {.READ}, {.PRIVATE}, fd, 0)
	if p == posix.MAP_FAILED {
		fmt.eprintln("cannot mmap", path, posix.strerror())
		os.exit(1)
	}
	posix.posix_madvise(p, uint(size), .SEQUENTIAL)
	return ([^]u8)(p)[:size]
}

unmap_file :: proc(data: []u8) {
	if len(data) > 0 {posix.munmap(raw_data(data), uint(len(data)))}
}
