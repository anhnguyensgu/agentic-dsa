// Generates a large, deterministic sales CSV for the reader benchmark, plus
// `<out>.expected`: the per-city totals the readers must reproduce, tallied
// here while writing so the oracle does not depend on any CSV parser.
//
//   odin run gen -o:speed -- <out.csv> [rows]
//
// Columns: id,ts,user_id,city,amount,qty,note
// The data exercises RFC 4180 quoting: cities and notes with commas, escaped
// quotes (""), and notes with a newline inside the quotes.
package csvgen

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"

DEFAULT_ROWS :: 15_000_000

CITIES := [?]string {
	"Tokyo", "Delhi", "Shanghai", "Sao Paulo", "Mexico City", "Cairo", "Mumbai", "Beijing",
	"Dhaka", "Osaka", "New York", "Karachi", "Buenos Aires", "Chongqing", "Istanbul", "Kolkata",
	"Manila", "Lagos", "Rio de Janeiro", "Tianjin", "Kinshasa", "Guangzhou", "Los Angeles", "Moscow",
	"Shenzhen", "Lahore", "Bangalore", "Paris", "Bogota", "Jakarta", "Chennai", "Lima",
	"Bangkok", "Seoul", "Nagoya", "Hyderabad", "London", "Tehran", "Chicago", "Chengdu",
	"Nanjing", "Wuhan", "Ho Chi Minh City", "Luanda", "Ahmedabad", "Kuala Lumpur", "Xi'an", "Hong Kong",
	"Dongguan", "Hangzhou", "Foshan", "Shenyang", "Riyadh", "Baghdad", "Santiago", "Surat",
	"Madrid", "Suzhou", "Pune", "Harbin", "Houston", "Dallas", "Toronto", "Dar es Salaam",
	// These need quoting.
	"Washington, D.C.", "Hanoi, Vietnam", "Saint Petersburg, FL", `The "Big Apple"`,
}

NOTES_PLAIN := [?]string{"fast delivery", "gift", "repeat customer", "ok", "damaged box", "left at door"}
NOTES_QUOTED := [?]string {
	`"late, but fine"`,
	`"red, size M"`,
	`"two boxes, one missing"`,
	`"said ""thanks"" twice"`,
	`"labelled ""fragile"", handled with care"`,
}
NOTES_MULTILINE := [?]string{"\"line one\nline two\"", "\"call first,\nthen ring \"\"twice\"\"\""}

Agg :: struct {
	count, cents, qty: i64,
}

rng: u64 = 0x9E3779B97F4A7C15

next_u64 :: #force_inline proc() -> u64 {
	x := rng
	x ~= x >> 12
	x ~= x << 25
	x ~= x >> 27
	rng = x
	return x * 0x2545F4914F6CDD1D
}

below :: #force_inline proc(n: u64) -> u64 {
	return next_u64() % n
}

Writer :: struct {
	f:   ^os.File,
	buf: []u8,
	n:   int,
	total: i64,
}

flush :: proc(w: ^Writer) {
	_, err := os.write(w.f, w.buf[:w.n])
	if err != nil {
		fmt.eprintln("write failed:", err)
		os.exit(1)
	}
	w.total += i64(w.n)
	w.n = 0
}

put_str :: #force_inline proc(w: ^Writer, s: string) {
	copy(w.buf[w.n:], s)
	w.n += len(s)
}

put_byte :: #force_inline proc(w: ^Writer, b: u8) {
	w.buf[w.n] = b
	w.n += 1
}

put_uint :: proc(w: ^Writer, v: u64) {
	tmp: [20]u8
	i := len(tmp)
	v := v
	for {
		i -= 1
		tmp[i] = '0' + u8(v % 10)
		v /= 10
		if v == 0 {break}
	}
	put_str(w, string(tmp[i:]))
}

put_2d :: #force_inline proc(w: ^Writer, v: u64) {
	put_byte(w, '0' + u8(v / 10))
	put_byte(w, '0' + u8(v % 10))
}

// RFC 4180 encoding: quote when the value holds a comma, quote or newline.
encode_field :: proc(s: string) -> string {
	if strings.index_any(s, ",\"\n") < 0 {
		return s
	}
	b := strings.builder_make()
	strings.write_byte(&b, '"')
	for c in transmute([]u8)s {
		if c == '"' {strings.write_byte(&b, '"')}
		strings.write_byte(&b, c)
	}
	strings.write_byte(&b, '"')
	return strings.to_string(b)
}

main :: proc() {
	if len(os.args) < 2 {
		fmt.eprintln("usage: gen <out.csv> [rows]")
		os.exit(2)
	}
	path := os.args[1]
	rows := DEFAULT_ROWS
	if len(os.args) >= 3 {
		ok: bool
		rows, ok = strconv.parse_int(os.args[2])
		if !ok || rows < 0 {
			fmt.eprintln("rows must be a non-negative integer")
			os.exit(2)
		}
	}

	encoded: [len(CITIES)]string
	for c, i in CITIES {encoded[i] = encode_field(c)}
	totals: [len(CITIES)]Agg

	f, err := os.create(path)
	if err != nil {
		fmt.eprintln("cannot create", path, err)
		os.exit(1)
	}
	w := Writer{f = f, buf = make([]u8, 8 << 20)}
	put_str(&w, "id,ts,user_id,city,amount,qty,note\n")

	for id in 1 ..= rows {
		put_uint(&w, u64(id))
		put_str(&w, ",2026-")
		put_2d(&w, 1 + below(12))
		put_byte(&w, '-')
		put_2d(&w, 1 + below(28))
		put_byte(&w, 'T')
		put_2d(&w, below(24))
		put_byte(&w, ':')
		put_2d(&w, below(60))
		put_byte(&w, ':')
		put_2d(&w, below(60))
		put_str(&w, "Z,")
		put_uint(&w, 1 + below(1_000_000))
		put_byte(&w, ',')

		// Skewed city choice: the first 16 cities get half the rows.
		ci := below(2) == 0 ? below(16) : below(len(CITIES))
		put_str(&w, encoded[ci])
		put_byte(&w, ',')

		cents := i64(below(1_000_000))
		if below(20) == 0 {cents = -i64(below(50_000))} // refunds
		if cents < 0 {put_byte(&w, '-')}
		mag := u64(abs(cents))
		put_uint(&w, mag / 100)
		put_byte(&w, '.')
		put_2d(&w, mag % 100)
		put_byte(&w, ',')

		qty := 1 + below(20)
		put_uint(&w, qty)
		put_byte(&w, ',')

		switch r := below(100); {
		case r < 50: // empty note
		case r < 80: put_str(&w, NOTES_PLAIN[below(len(NOTES_PLAIN))])
		case r < 99: put_str(&w, NOTES_QUOTED[below(len(NOTES_QUOTED))])
		case:        put_str(&w, NOTES_MULTILINE[below(len(NOTES_MULTILINE))])
		}
		put_byte(&w, '\n')

		t := &totals[ci]
		t.count += 1
		t.cents += cents
		t.qty += i64(qty)

		if w.n > len(w.buf) - 1024 {flush(&w)}
	}
	flush(&w)
	os.close(f)

	order: [len(CITIES)]int
	for i in 0 ..< len(order) {order[i] = i}
	slice.sort_by(order[:], proc(a, b: int) -> bool {return CITIES[a] < CITIES[b]})
	b := strings.builder_make()
	for i in order {
		t := totals[i]
		if t.count == 0 {continue}
		fmt.sbprintf(&b, "%s\t%d\t%d\t%d\n", CITIES[i], t.count, t.cents, t.qty)
	}
	expected_path := strings.concatenate({path, ".expected"})
	if werr := os.write_entire_file(expected_path, transmute([]u8)strings.to_string(b)); werr != nil {
		fmt.eprintln("cannot write", expected_path, werr)
		os.exit(1)
	}
	fmt.printfln("wrote %s: %d rows, %.1f MB (+ %s)", path, rows, f64(w.total) / 1e6, expected_path)
}
