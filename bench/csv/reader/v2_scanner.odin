package csvbench

import "core:math"
import "core:strconv"

// v2-v5 share one byte-at-a-time RFC 4180 scanner over the in-memory file.
// Fields are slices into the buffer (only a quoted field holding "" is copied),
// and only the three columns the query needs are kept. What happens to a
// finished record is the part each step changes.
Sink_Mode :: enum {
	Map_Strconv,  // v2: map[string] + strconv
	Map_Fast_Num, // v3: map[string] + hand-written number parsing
	Table,        // v4+: custom hash table + hand-written number parsing
}

Sink :: struct {
	m: map[string]Agg,
	t: Table,
}

on_record :: #force_inline proc(s: ^Sink, $MODE: Sink_Mode, city, amount, qty: string) {
	when MODE == .Map_Strconv {
		a, _ := strconv.parse_f64(amount)
		q, _ := strconv.parse_int(qty)
		map_add(&s.m, city, i64(math.round(a * 100)), i64(q))
	} else when MODE == .Map_Fast_Num {
		map_add(&s.m, city, parse_cents(amount), parse_uint(qty))
	} else {
		table_add(&s.t, city, parse_cents(amount), parse_uint(qty))
	}
}

scan_bytes :: proc(data: []u8, s: ^Sink, $MODE: Sink_Mode) {
	scratch := make([dynamic]u8, 0, 64)
	defer delete(scratch)
	n := len(data)
	pos := 0
	header := true
	city, amount, qty: string
	for pos < n {
		col := 0
		for {
			start, end: int
			escaped := false
			if pos < n && data[pos] == '"' {
				pos += 1
				start = pos
				for pos < n {
					if data[pos] == '"' {
						if pos + 1 < n && data[pos + 1] == '"' {
							escaped = true
							pos += 2
							continue
						}
						break
					}
					pos += 1
				}
				end = pos
				pos += 1 // closing quote
			} else {
				start = pos
				for pos < n && data[pos] != ',' && data[pos] != '\n' {pos += 1}
				end = pos
			}
			switch col {
			case COL_CITY:   city = escaped ? unescape(data[start:end], &scratch) : string(data[start:end])
			case COL_AMOUNT: amount = string(data[start:end])
			case COL_QTY:    qty = string(data[start:end])
			}
			if pos >= n || data[pos] == '\n' {
				pos += 1
				break
			}
			pos += 1 // ','
			col += 1
		}
		if header {
			header = false
			continue
		}
		on_record(s, MODE, city, amount, qty)
	}
}

// v5: identical to scan_bytes in Table mode, minus bounds checks.
scan_bytes_nbc :: proc(data: []u8, s: ^Sink) #no_bounds_check {
	scratch := make([dynamic]u8, 0, 64)
	defer delete(scratch)
	n := len(data)
	pos := 0
	header := true
	city, amount, qty: string
	for pos < n {
		col := 0
		for {
			start, end: int
			escaped := false
			if pos < n && data[pos] == '"' {
				pos += 1
				start = pos
				for pos < n {
					if data[pos] == '"' {
						if pos + 1 < n && data[pos + 1] == '"' {
							escaped = true
							pos += 2
							continue
						}
						break
					}
					pos += 1
				}
				end = pos
				pos += 1
			} else {
				start = pos
				for pos < n && data[pos] != ',' && data[pos] != '\n' {pos += 1}
				end = pos
			}
			switch col {
			case COL_CITY:   city = escaped ? unescape(data[start:end], &scratch) : string(data[start:end])
			case COL_AMOUNT: amount = string(data[start:end])
			case COL_QTY:    qty = string(data[start:end])
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
		on_record(s, .Table, city, amount, qty)
	}
}

// v2: hand-written scanner, zero-copy fields; still strconv + map[string].
v2_scanner :: proc(path: string) -> Result {
	data := read_file(path)
	defer delete(data)
	s := Sink{m = make(map[string]Agg)}
	defer map_destroy(s.m)
	scan_bytes(data, &s, .Map_Strconv)
	return result_from_map(s.m)
}

// v3: + integer-cents and integer parsing by hand instead of strconv.
v3_fast_numbers :: proc(path: string) -> Result {
	data := read_file(path)
	defer delete(data)
	s := Sink{m = make(map[string]Agg)}
	defer map_destroy(s.m)
	scan_bytes(data, &s, .Map_Fast_Num)
	return result_from_map(s.m)
}

// v4: + open-addressing table instead of map[string].
v4_hash_table :: proc(path: string) -> Result {
	data := read_file(path)
	defer delete(data)
	s := Sink{t = table_make()}
	defer table_destroy(&s.t)
	scan_bytes(data, &s, .Table)
	return result_from_table(&s.t)
}

// v5: + #no_bounds_check on the scan loop.
v5_no_bounds_check :: proc(path: string) -> Result {
	data := read_file(path)
	defer delete(data)
	s := Sink{t = table_make()}
	defer table_destroy(&s.t)
	scan_bytes_nbc(data, &s)
	return result_from_table(&s.t)
}
