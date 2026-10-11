package main

import "core:os"
import "core:strconv"

// ======================= fast input =======================
// Read all of stdin with large read() calls, then parse from memory.
// A 0 byte sentinel after the data lets every scan loop stop without a
// separate `pos < len` check.

input: []u8 // stdin bytes followed by one 0 sentinel
ipos: int

read_input :: proc() {
	buf := make([]u8, 1 << 16)
	n := 0
	for {
		if n == len(buf) - 1 { 	// always keep one byte free for the sentinel
			bigger := make([]u8, 2 * len(buf))
			copy(bigger, buf[:n])
			delete(buf)
			buf = bigger
		}
		r, err := os.read(os.stdin, buf[n:len(buf) - 1])
		n += r
		if err != nil || r == 0 {break}
	}
	buf[n] = 0
	input = buf[:n + 1]
	ipos = 0
}

skip_space :: #force_inline proc() #no_bounds_check {
	for input[ipos] != 0 && input[ipos] <= ' ' {ipos += 1}
}

// true when only whitespace is left
at_eof :: proc() -> bool {
	skip_space()
	return ipos >= len(input) - 1
}

read_int :: proc() -> int #no_bounds_check {
	skip_space()
	neg := input[ipos] == '-'
	if neg || input[ipos] == '+' {ipos += 1}
	x := 0
	for {
		d := input[ipos] - '0' // u8 wraps, so any non-digit (and the sentinel) is > 9
		if d > 9 {break}
		x = x * 10 + int(d)
		ipos += 1
	}
	return -x if neg else x
}

// Zero-copy: the string points into `input`, valid for the whole run.
read_word :: proc() -> string #no_bounds_check {
	skip_space()
	start := ipos
	for input[ipos] > ' ' {ipos += 1}
	return string(input[start:ipos])
}

// Rest of the current line, without the '\n' or a trailing '\r'.
read_line :: proc() -> string #no_bounds_check {
	start := ipos
	for input[ipos] != '\n' && input[ipos] != 0 {ipos += 1}
	end := ipos
	if input[ipos] == '\n' {ipos += 1}
	if end > start && input[end - 1] == '\r' {end -= 1}
	return string(input[start:end])
}

read_f64 :: proc() -> f64 {
	v, _ := strconv.parse_f64(read_word())
	return v
}

// ======================= fast output =======================
// One 64 KiB buffer; os.write only when it fills up and once at exit.

out_buf: [1 << 16]u8
out_len: int

flush :: proc() {
	if out_len > 0 {
		os.write(os.stdout, out_buf[:out_len])
		out_len = 0
	}
}

write_byte :: #force_inline proc(c: u8) {
	if out_len == len(out_buf) {flush()}
	out_buf[out_len] = c
	out_len += 1
}

write_string :: proc(s: string) {
	if out_len + len(s) > len(out_buf) {
		flush()
		if len(s) > len(out_buf) {
			os.write(os.stdout, transmute([]u8)s)
			return
		}
	}
	copy(out_buf[out_len:], s)
	out_len += len(s)
}

write_int :: proc(x: int) #no_bounds_check {
	if out_len + 20 > len(out_buf) {flush()} 	// 19 digits + sign
	u := u64(x)
	if x < 0 {
		u = ~u + 1 // also correct for min(int)
		out_buf[out_len] = '-'
		out_len += 1
	}
	tmp: [20]u8
	i := len(tmp)
	for {
		i -= 1
		tmp[i] = u8('0' + u % 10)
		u /= 10
		if u == 0 {break}
	}
	copy(out_buf[out_len:], tmp[i:])
	out_len += len(tmp) - i
}

write_f64 :: proc(x: f64, prec := 6) {
	tmp: [64]u8
	s := strconv.write_float(tmp[:], x, 'f', prec, 64)
	if len(s) > 0 && s[0] == '+' {s = s[1:]} 	// write_float always emits a sign
	write_string(s)
}

// ======================= solution =======================

main :: proc() {
	read_input()
	defer flush()

	// n := read_int()
	// write_int(n)
	// write_byte('\n')
}
