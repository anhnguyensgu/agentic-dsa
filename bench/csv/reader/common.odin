package csvbench

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strings"

// Query every version answers: per city, the row count, the amount summed in
// integer cents, and the quantity sum.
COL_CITY :: 3
COL_AMOUNT :: 4
COL_QTY :: 5

Agg :: struct {
	count, cents, qty: i64,
}

City_Total :: struct {
	city:     string, // owned
	using agg: Agg,
}

Result :: [dynamic]City_Total

result_destroy :: proc(r: Result) {
	for t in r {delete(t.city)}
	delete(r)
}

// Same layout as gen's `.expected` file so results compare as strings.
result_format :: proc(r: Result) -> string {
	slice.sort_by(r[:], proc(a, b: City_Total) -> bool {return a.city < b.city})
	b := strings.builder_make()
	for t in r {
		fmt.sbprintf(&b, "%s\t%d\t%d\t%d\n", t.city, t.count, t.cents, t.qty)
	}
	return strings.to_string(b)
}

result_from_map :: proc(m: map[string]Agg) -> Result {
	r := make(Result, 0, len(m))
	for k, v in m {append(&r, City_Total{city = strings.clone(k), agg = v})}
	return r
}

map_add :: #force_inline proc(m: ^map[string]Agg, city: string, cents, qty: i64) {
	key, val, inserted, _ := map_entry(m, city)
	if inserted {key^ = strings.clone(city)} // city points into a reused buffer
	val.count += 1
	val.cents += cents
	val.qty += qty
}

map_destroy :: proc(m: map[string]Agg) {
	for k in m {delete(k)}
	delete(m)
}

// Contents of a quoted field with each "" collapsed to ". Reuses scratch.
unescape :: proc(s: []u8, scratch: ^[dynamic]u8) -> string {
	clear(scratch)
	for i := 0; i < len(s); i += 1 {
		append(scratch, s[i])
		if s[i] == '"' {i += 1}
	}
	return string(scratch[:])
}

read_file :: proc(path: string) -> []u8 {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil {
		fmt.eprintln("cannot read", path, err)
		os.exit(1)
	}
	return data
}

// "-12.34" -> -1234. Accepts 0-2 fraction digits; no strconv, no floats.
parse_cents :: #force_inline proc(s: string) -> i64 {
	i := 0
	neg := len(s) > 0 && s[0] == '-'
	if neg {i = 1}
	v: i64 = 0
	for i < len(s) && s[i] != '.' {
		v = v * 10 + i64(s[i] - '0')
		i += 1
	}
	frac := 0
	if i < len(s) {
		i += 1
		for i < len(s) && frac < 2 {
			v = v * 10 + i64(s[i] - '0')
			i += 1
			frac += 1
		}
	}
	for frac < 2 {
		v *= 10
		frac += 1
	}
	return neg ? -v : v
}

parse_uint :: #force_inline proc(s: string) -> i64 {
	v: i64 = 0
	for c in transmute([]u8)s {v = v * 10 + i64(c - '0')}
	return v
}

// Open-addressing table for the group-by key. Stores the full hash so most
// probes reject on one integer compare before touching key bytes.
Slot :: struct {
	hash:     u64, // 0 = empty
	key:      string,
	a, b:     u64, // key words for v9's lookup (see Key)
	using agg: Agg,
}

Table :: struct {
	slots: []Slot,
	count: int,
}

table_make :: proc(cap := 1024) -> Table {
	assert(cap & (cap - 1) == 0)
	return Table{slots = make([]Slot, cap)}
}

table_destroy :: proc(t: ^Table) {
	for s in t.slots {if s.hash != 0 {delete(s.key)}}
	delete(t.slots)
}

hash_key :: #force_inline proc "contextless" (s: string) -> u64 {
	h: u64 = 0xcbf29ce484222325
	for c in transmute([]u8)s {h = (h ~ u64(c)) * 0x100000001b3}
	h ~= h >> 32
	return h | 1
}

table_get :: #force_inline proc(t: ^Table, key: string) -> ^Agg {
	h := hash_key(key)
	mask := u64(len(t.slots) - 1)
	i := h & mask
	for {
		s := &t.slots[i]
		if s.hash == h && s.key == key {return &s.agg}
		if s.hash == 0 {return table_insert(t, key, h)}
		i = (i + 1) & mask
	}
}

// Slow path, once per distinct key.
table_insert :: proc(t: ^Table, key: string, h: u64) -> ^Agg {
	if (t.count + 1) * 2 > len(t.slots) {table_grow(t)}
	mask := u64(len(t.slots) - 1)
	i := h & mask
	for t.slots[i].hash != 0 {i = (i + 1) & mask}
	s := &t.slots[i]
	s.hash = h
	s.key = strings.clone(key)
	k := key_from_string(s.key)
	s.a, s.b = k.a, k.b
	t.count += 1
	return &s.agg
}

table_grow :: proc(t: ^Table) {
	old := t.slots
	t.slots = make([]Slot, 2 * len(old))
	mask := u64(len(t.slots) - 1)
	for s in old {
		if s.hash == 0 {continue}
		i := s.hash & mask
		for t.slots[i].hash != 0 {i = (i + 1) & mask}
		t.slots[i] = s
	}
	delete(old)
}

table_add :: #force_inline proc(t: ^Table, city: string, cents, qty: i64) {
	a := table_get(t, city)
	a.count += 1
	a.cents += cents
	a.qty += qty
}

// Adds src into dst (used to combine per-thread tables).
table_merge :: proc(dst, src: ^Table) {
	for s in src.slots {
		if s.hash == 0 {continue}
		a := table_get(dst, s.key)
		a.count += s.count
		a.cents += s.cents
		a.qty += s.qty
	}
}

result_from_table :: proc(t: ^Table) -> Result {
	r := make(Result, 0, t.count)
	for s in t.slots {
		if s.hash != 0 {append(&r, City_Total{city = strings.clone(s.key), agg = s.agg})}
	}
	return r
}
