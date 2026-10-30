package csvbench

import "base:intrinsics"

// v13: v12 with cheaper number parsing. Profiling v12 put number parsing on
// top (29% of core time, ~11 ns a row): v11's parser ran the full 8-byte
// routine three times a row (amount's whole part, its 2 cents digits, qty),
// each a chain of three dependent multiplies.
//
// Here amount takes one pass: drop the '.' from the loaded word and parse
// every digit at once as cents. qty, nearly always 1 or 2 digits, is read
// directly; longer values still use swar_uint.

// "-1234.56" -> -123456 in one digit pass. Needs e >= 8 and the format
// -?d*.dd in at most 8 bytes; otherwise returns ok = false.
swar_amount :: #force_inline proc "contextless" (data: []u8, s, e: int) -> (v: i64, ok: bool) #no_bounds_check {
	n := e - s
	if e < 8 || n < 4 || n > 8 || data[e - 3] != '.' {return 0, false}
	neg := data[s] == '-'
	m := n - 1 - int(neg) // digits once the '.' and sign are gone
	w := intrinsics.unaligned_load((^u64)(&data[e - 8]))
	// The '.' is byte 5 (e - 3). Move bytes 0-4 up one to close the gap;
	// the cents stay in bytes 6-7, so the digits become the top m bytes.
	w = (w & 0x000000FF_FFFFFFFF) << 8 | (w & 0xFFFF0000_00000000)
	keep := ~u64(0) << (8 * uint(8 - m))
	d := (w & keep) - (0x3030303030303030 & keep)
	if ((d + 0x7676767676767676) | d) & 0x8080808080808080 & keep != 0 {return 0, false}
	d = (d * 10 + (d >> 8)) & 0x00FF00FF00FF00FF
	d = (d * 100 + (d >> 16)) & 0x0000FFFF0000FFFF
	d = (d * 10000 + (d >> 32)) & 0xFFFFFFFF
	return neg ? -i64(d) : i64(d), true
}

// 1 or 2 digits without a loop or a length-dependent branch (the length
// test only fails for other widths, which go to swar_uint).
small_uint :: #force_inline proc "contextless" (data: []u8, s, e: int) -> (v: i64, ok: bool) #no_bounds_check {
	n := e - s
	if n < 1 || n > 2 || e < 2 {return swar_uint(data, s, e)}
	lo := i64(data[e - 1]) - '0'
	hi := i64(data[e - 2]) - '0'
	hi = n == 2 ? hi : 0 // for 1 digit, data[e - 2] is the separator
	return hi * 10 + lo, u64(lo) <= 9 && u64(hi) <= 9
}

v13_fused_parse :: proc(path: string) -> Result {
	return scan_speculative(path, .Fused_Parse)
}
