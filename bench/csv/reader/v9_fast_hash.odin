package csvbench

import "base:intrinsics"

// v9: + branch-free key lookup. Removing one piece at a time from v8 showed the
// table lookup was its largest cost (~22 ns a record). The FNV-1a loop, the
// memcmp in the key compare, and any branch on the key's length all run a
// data-dependent number of steps, and with city names of random length they
// mispredict on nearly every record.
//
// Here a key of up to 16 bytes is two words: a = its first 8 bytes (zero
// masked if shorter), b = its last 8 bytes (0 if shorter than 8). Both are
// read in place from the file buffer, the hash is two multiplies, and a slot
// compare is three integer compares. Longer keys, keys at the very edge of
// the buffer, and unescaped keys take a slower path that yields the same words.

Key :: struct {
	a, b: u64,
	n:    int,
	s:    string, // compared byte-wise only when n > 16
}

load_u64 :: #force_inline proc "contextless" (p: rawptr) -> u64 {
	return intrinsics.unaligned_load((^u64)(p))
}

low_bytes_mask :: #force_inline proc "contextless" (n: int) -> u64 {
	return ~u64(0) >> (64 - 8 * uint(min(n, 8))) // n = 0 shifts by 64, which Odin defines as 0
}

key_from_string :: proc(s: string) -> Key #no_bounds_check {
	n := len(s)
	k := Key{n = n, s = s}
	if n <= 16 {
		tmp: [24]u8
		copy(tmp[:], s)
		k.a = load_u64(&tmp[0]) & low_bytes_mask(n)
		if n >= 8 {k.b = load_u64(&tmp[n - 8])}
	} else {
		k.a = load_u64(raw_data(s))
		k.b = load_u64(&raw_data(s)[n - 8])
	}
	return k
}

// The field data[start:end]. Reads up to 8 bytes either side of the field,
// so it falls back to key_from_string within 8 bytes of the buffer's ends.
key_in_buffer :: #force_inline proc(data: []u8, start, end: int) -> Key #no_bounds_check {
	n := end - start
	if start + 8 > len(data) || end < 8 || n > 16 {
		return key_from_string(string(data[start:end]))
	}
	lo := load_u64(&data[start])
	hi := load_u64(&data[end - 8])
	return Key{a = lo & low_bytes_mask(n), b = n >= 8 ? hi : 0, n = n, s = string(data[start:end])}
}

key_hash :: #force_inline proc "contextless" (k: Key) -> u64 #no_bounds_check {
	a := k.a
	if k.n > 16 { 	// rare: fold in the middle bytes
		p := raw_data(k.s)
		for i := 8; i + 8 < k.n; i += 8 {a = (a ~ load_u64(&p[i])) * 0x9E3779B97F4A7C15}
	}
	h := (a ~ 0x9E3779B97F4A7C15) * (k.b ~ u64(k.n) ~ 0xD6E8FEB86659FD93)
	h ~= h >> 32
	return h | 1
}

table_add_key :: #force_inline proc(t: ^Table, k: Key, cents, qty: i64) #no_bounds_check {
	h := key_hash(k)
	mask := u64(len(t.slots) - 1)
	i := h & mask
	a: ^Agg
	for {
		s := &t.slots[i]
		if s.hash == h && s.a == k.a && s.b == k.b && len(s.key) == k.n && (k.n <= 16 || s.key == k.s) {
			a = &s.agg
			break
		}
		if s.hash == 0 {
			a = table_insert(t, k.s, h)
			break
		}
		i = (i + 1) & mask
	}
	a.count += 1
	a.cents += cents
	a.qty += qty
}

v9_fast_hash :: proc(path: string) -> Result {
	data := map_file(path)
	defer unmap_file(data)
	t := table_make()
	defer table_destroy(&t)
	scan_index(data, &t, true, Scan_Level.Fast_Hash)
	return result_from_table(&t)
}
