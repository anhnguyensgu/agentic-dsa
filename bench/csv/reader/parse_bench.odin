package csvbench

import "core:fmt"
import "core:math"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:time"

// Parsing micro-benchmark: reader <file.csv> -parse [-runs:N] [-rows:N]
//
// Finds the amount and qty field bounds and a city id of the first N rows
// (default PARSE_ROWS) once (untimed), then times each way of turning those fields into
// per-city sums. Parsers read the bytes from the mapped file, as the readers
// do; the "touch" floor reads the same bytes without parsing them. With few
// enough rows (~100K) the bytes stay in L2 and only the parsing is measured;
// with millions they stream from memory as in the real readers.

PARSE_ROWS :: 2_000_000

Row_Fields :: struct {
	a_s, a_e, q_s, q_e: u32, // amount and qty bounds in the file
	city:               u16,
}

extract_rows :: proc(data: []u8, max_rows: int) -> (rows: [dynamic]Row_Fields, ncities: int) {
	cities := make(map[string]u16)
	defer {
		for k in cities {delete(k)}
		delete(cities)
	}
	scratch := make([dynamic]u8, 0, 64)
	defer delete(scratch)
	n := len(data)
	pos := 0
	header := true
	for pos < n && len(rows) < max_rows {
		r: Row_Fields
		city: string
		col := 0
		for {
			start := pos
			if pos < n && data[pos] == '"' {
				pos += 1
				for pos < n {
					if data[pos] == '"' {
						if pos + 1 < n && data[pos + 1] == '"' {
							pos += 2
							continue
						}
						break
					}
					pos += 1
				}
				pos += 1
			} else {
				for pos < n && data[pos] != ',' && data[pos] != '\n' {pos += 1}
			}
			switch col {
			case COL_CITY:   city = field(data, start, pos, &scratch)
			case COL_AMOUNT: r.a_s, r.a_e = u32(start), u32(pos)
			case COL_QTY:    r.q_s, r.q_e = u32(start), u32(pos)
			}
			if pos >= n || data[pos] == '\n' {
				pos += 1
				break
			}
			pos += 1
			col += 1
		}
		if header {
			header = false
			continue
		}
		id, found := cities[city]
		if !found {
			id = u16(len(cities))
			cities[strings.clone(city)] = id
		}
		r.city = id
		append(&rows, r)
	}
	return rows, len(cities)
}

// Field text without surrounding quotes (the fallback parsers take strings).
field_text :: #force_inline proc(data: []u8, s, e: u32) -> string #no_bounds_check {
	if e - s >= 2 && data[s] == '"' {return string(data[s + 1:e - 1])}
	return string(data[s:e])
}

// --- amount parsers: each adds every row's amount in cents to out[city] ---

amount_touch :: proc(data: []u8, rows: []Row_Fields, out: []i64) #no_bounds_check {
	for r in rows {out[r.city] += i64(data[r.a_e - 1])}
}

amount_strconv :: proc(data: []u8, rows: []Row_Fields, out: []i64) #no_bounds_check {
	for r in rows {
		v, _ := strconv.parse_f64(field_text(data, r.a_s, r.a_e))
		out[r.city] += i64(math.round(v * 100))
	}
}

amount_loop :: proc(data: []u8, rows: []Row_Fields, out: []i64) #no_bounds_check {
	for r in rows {out[r.city] += parse_cents(field_text(data, r.a_s, r.a_e))}
}

amount_swar_two :: proc(data: []u8, rows: []Row_Fields, out: []i64) #no_bounds_check {
	for r in rows {
		v, ok := swar_cents(data, int(r.a_s), int(r.a_e))
		if !ok {v = parse_cents(field_text(data, r.a_s, r.a_e))}
		out[r.city] += v
	}
}

amount_swar_one :: proc(data: []u8, rows: []Row_Fields, out: []i64) #no_bounds_check {
	for r in rows {
		v, ok := swar_amount(data, int(r.a_s), int(r.a_e))
		if !ok {v = parse_cents(field_text(data, r.a_s, r.a_e))}
		out[r.city] += v
	}
}

// Deferred conversion: only the per-city sum is needed, so add each row's
// digits position by position and weight the positions once per flush.
Digit_Sums :: struct {
	lanes: [2][2]u64, // [is negative][even, odd bytes]: digit sums in 16-bit lanes
	rows:  int,
	cents: i64,
}

DIGIT_FLUSH_ROWS :: 4096 // 4096 * 9 still fits a 16-bit lane

POW10 := [8]i64{1, 10, 100, 1_000, 10_000, 100_000, 1_000_000, 10_000_000}

// Byte k of a digit word is worth 10^(7-k): the cents digit is byte 7.
digit_sums_flush :: proc(ds: ^Digit_Sums) {
	for sign in 0 ..< 2 {
		total: i64 = 0
		for half in 0 ..< 2 {
			w := ds.lanes[sign][half]
			for j in 0 ..< 4 {
				total += i64((w >> (16 * uint(j))) & 0xFFFF) * POW10[7 - (2 * j + half)]
			}
		}
		ds.cents += sign == 0 ? total : -total
	}
	ds.lanes = {}
	ds.rows = 0
}

// Same checks and digit word as swar_amount, then two adds instead of the
// three multiply steps.
digit_sums_add :: #force_inline proc(ds: ^Digit_Sums, data: []u8, s, e: int) -> bool #no_bounds_check {
	n := e - s
	if e < 8 || n < 4 || n > 8 || data[e - 3] != '.' {return false}
	neg := int(data[s] == '-')
	m := n - 1 - neg
	w := load_u64(&data[e - 8])
	w = (w & 0x000000FF_FFFFFFFF) << 8 | (w & 0xFFFF0000_00000000)
	keep := ~u64(0) << (8 * uint(8 - m))
	d := (w & keep) - (0x3030303030303030 & keep)
	if ((d + 0x7676767676767676) | d) & 0x8080808080808080 & keep != 0 {return false}
	ds.lanes[neg][0] += d & 0x00FF00FF00FF00FF
	ds.lanes[neg][1] += (d >> 8) & 0x00FF00FF00FF00FF
	ds.rows += 1
	if ds.rows == DIGIT_FLUSH_ROWS {digit_sums_flush(ds)}
	return true
}

amount_digit_sums :: proc(data: []u8, rows: []Row_Fields, out: []i64) #no_bounds_check {
	sums := make([]Digit_Sums, len(out))
	defer delete(sums)
	for r in rows {
		ds := &sums[r.city]
		if !digit_sums_add(ds, data, int(r.a_s), int(r.a_e)) {
			ds.cents += parse_cents(field_text(data, r.a_s, r.a_e))
		}
	}
	for &ds, c in sums {
		digit_sums_flush(&ds)
		out[c] += ds.cents
	}
}

// --- qty parsers ---

qty_touch :: proc(data: []u8, rows: []Row_Fields, out: []i64) #no_bounds_check {
	for r in rows {out[r.city] += i64(data[r.q_e - 1])}
}

qty_strconv :: proc(data: []u8, rows: []Row_Fields, out: []i64) #no_bounds_check {
	for r in rows {
		v, _ := strconv.parse_int(field_text(data, r.q_s, r.q_e))
		out[r.city] += i64(v)
	}
}

qty_loop :: proc(data: []u8, rows: []Row_Fields, out: []i64) #no_bounds_check {
	for r in rows {out[r.city] += parse_uint(field_text(data, r.q_s, r.q_e))}
}

qty_swar :: proc(data: []u8, rows: []Row_Fields, out: []i64) #no_bounds_check {
	for r in rows {
		v, ok := swar_uint(data, int(r.q_s), int(r.q_e))
		if !ok {v = parse_uint(field_text(data, r.q_s, r.q_e))}
		out[r.city] += v
	}
}

qty_small :: proc(data: []u8, rows: []Row_Fields, out: []i64) #no_bounds_check {
	for r in rows {
		v, ok := small_uint(data, int(r.q_s), int(r.q_e))
		if !ok {v = parse_uint(field_text(data, r.q_s, r.q_e))}
		out[r.city] += v
	}
}

Parser :: struct {
	name, used_by: string,
	run:           proc(data: []u8, rows: []Row_Fields, out: []i64),
	floor:         bool, // reads the bytes only; not checked
}

AMOUNT_PARSERS := [?]Parser {
	{"touch bytes only", "floor", amount_touch, true},
	{"strconv.parse_f64", "v0-v2", amount_strconv, false},
	{"digit loop", "v3-v10", amount_loop, false},
	{"SWAR, two calls", "v11-v12", amount_swar_two, false},
	{"SWAR, one pass", "v13", amount_swar_one, false},
	{"digit sums, no multiply", "v14 idea", amount_digit_sums, false},
}

QTY_PARSERS := [?]Parser {
	{"touch bytes only", "floor", qty_touch, true},
	{"strconv.parse_int", "v0-v2", qty_strconv, false},
	{"digit loop", "v3-v10", qty_loop, false},
	{"SWAR 8-byte", "v11-v12", qty_swar, false},
	{"1-2 digits direct", "v13", qty_small, false},
}

parse_bench :: proc(path: string, runs: int, max_rows: int) -> bool {
	data := map_file(path)
	defer unmap_file(data)
	rows, ncities := extract_rows(data, max_rows)
	defer delete(rows)
	fmt.printfln("%s: first %d rows, %d cities, single thread, best of %d runs\n", path, len(rows), ncities, runs)

	all_ok := true
	for group in 0 ..< 2 {
		parsers := group == 0 ? AMOUNT_PARSERS[:] : QTY_PARSERS[:]
		fmt.printfln("%-26s %-9s %9s %9s %8s %10s  %s", group == 0 ? "amount" : "qty", "used by", "best ms", "ns/row", "net ns", "vs strconv", "check")
		out := make([]i64, ncities)
		defer delete(out)
		reference := make([]i64, ncities)
		defer delete(reference)
		parsers[len(parsers) - 1].run(data, rows[:], reference) // checked against every other parser

		// Round-robin: each round runs every parser once, so VM speed drift
		// hits all of them alike instead of whichever ran during a slow spell.
		times := make([][]f64, len(parsers))
		defer {
			for t in times {delete(t)}
			delete(times)
		}
		for &t in times {t = make([]f64, runs)}
		ok := make([]bool, len(parsers))
		defer delete(ok)
		slice.fill(ok, true)
		for r in 0 ..< runs {
			for p, i in parsers {
				slice.zero(out)
				start := time.tick_now()
				p.run(data, rows[:], out)
				times[i][r] = time.duration_milliseconds(time.tick_since(start))
				if !p.floor && !slice.equal(out, reference) {ok[i] = false}
			}
		}

		floor_ns, strconv_ns: f64
		for p, i in parsers {
			slice.sort(times[i])
			ns := times[i][0] * 1e6 / f64(len(rows))
			if p.floor {floor_ns = ns}
			if strconv_ns == 0 && !p.floor {strconv_ns = ns}
			fmt.printfln(
				"%-26s %-9s %9s %9s %8s %10s  %s",
				p.name,
				p.used_by,
				fmt.tprintf("%.1f", times[i][0]),
				fmt.tprintf("%.2f", ns),
				p.floor ? "" : fmt.tprintf("%.2f", ns - floor_ns),
				p.floor ? "" : fmt.tprintf("%.1fx", strconv_ns / ns),
				p.floor ? "" : (ok[i] ? "ok" : "WRONG"),
			)
			all_ok &&= ok[i]
		}
		fmt.println()
	}
	return all_ok
}
