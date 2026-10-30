package csvbench

import "base:intrinsics"

// v11: v10 plus the two fixes profiling found (perf sampling for time,
// cachegrind for simulated branch mispredictions):
//
// 1. Prefetch. 81% of v9's scan-loop samples sat on the 64-byte load from the
//    file. The classification-only floor streams the same bytes in 150 ms
//    because nothing else is in flight; v9's index stores and record work
//    leave fewer loads outstanding, so memory latency shows. Asking for the
//    block PREFETCH_DISTANCE ahead hides it (512 B to 4 KB all helped; 2 KB
//    was best, MAP_POPULATE did nothing).
//
// 2. Branch-free numbers. parse_cents and parse_uint loop once per digit,
//    and amount/qty lengths are random, so the loop exits mispredict:
//    ~1.5 of the 2.35 mispredicts per row. swar_uint reads the 8 bytes ending
//    at the field, keeps the field's bytes, and combines all digits with
//    three multiplies, whatever the length.

PREFETCH_DISTANCE :: 2048

// data[s:e] as an unsigned number when it is 1 to 8 ASCII digits.
// Needs e >= 8 (it loads the 8 bytes before e); otherwise returns ok = false.
swar_uint :: #force_inline proc "contextless" (data: []u8, s, e: int) -> (v: i64, ok: bool) #no_bounds_check {
	n := e - s
	if e < 8 || n < 1 || n > 8 {return 0, false}
	w := intrinsics.unaligned_load((^u64)(&data[e - 8]))
	keep := ~u64(0) << (8 * uint(8 - n)) // the field is the top n bytes
	d := (w & keep) - (0x3030303030303030 & keep)
	// Each kept byte must now be 0..9: a borrow or a value above 9 sets the
	// byte's top bit in d or in d + 0x76.
	if ((d + 0x7676767676767676) | d) & 0x8080808080808080 & keep != 0 {return 0, false}
	// The first character is the lowest byte, so combine neighbours:
	// pairs (x10), then quads (x100), then halves (x10000).
	d = (d * 10 + (d >> 8)) & 0x00FF00FF00FF00FF
	d = (d * 100 + (d >> 16)) & 0x0000FFFF0000FFFF
	d = (d * 10000 + (d >> 32)) & 0xFFFFFFFF
	return i64(d), true
}

// "-1234.56" -> -123456 when the amount has exactly two decimals.
swar_cents :: #force_inline proc "contextless" (data: []u8, s, e: int) -> (v: i64, ok: bool) #no_bounds_check {
	if e - s < 4 || data[e - 3] != '.' {return 0, false}
	neg := data[s] == '-'
	whole, whole_ok := swar_uint(data, s + int(neg), e - 3)
	frac, frac_ok := swar_uint(data, e - 2, e)
	v = whole * 100 + frac
	return neg ? -v : v, whole_ok && frac_ok
}

v11_tuned :: proc(path: string) -> Result {
	return scan_threaded(path, tuned = true)
}
