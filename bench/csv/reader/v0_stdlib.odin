package csvbench

import "core:encoding/csv"
import "core:fmt"
import "core:math"
import "core:os"
import "core:strconv"

// v0: core:encoding/csv streaming from the file, strconv for numbers,
// map[string] for the group-by. What you would write first.
v0_stdlib_stream :: proc(path: string) -> Result {
	f, err := os.open(path)
	if err != nil {
		fmt.eprintln("cannot open", path, err)
		os.exit(1)
	}
	defer os.close(f)

	r: csv.Reader
	r.reuse_record = true
	r.reuse_record_buffer = true
	csv.reader_init(&r, os.to_stream(f))
	defer csv.reader_destroy(&r)
	return stdlib_aggregate(&r)
}

// v1: same parser, but the whole file is read into memory first.
v1_stdlib_memory :: proc(path: string) -> Result {
	data := read_file(path)
	defer delete(data)

	r: csv.Reader
	r.reuse_record = true
	r.reuse_record_buffer = true
	csv.reader_init_with_string(&r, string(data))
	defer csv.reader_destroy(&r)
	return stdlib_aggregate(&r)
}

stdlib_aggregate :: proc(r: ^csv.Reader) -> Result {
	m := make(map[string]Agg)
	defer map_destroy(m)
	header := true
	for rec in csv.iterator_next(r) {
		if header {
			header = false
			continue
		}
		amount, _ := strconv.parse_f64(rec[COL_AMOUNT])
		qty, _ := strconv.parse_int(rec[COL_QTY])
		map_add(&m, rec[COL_CITY], i64(math.round(amount * 100)), i64(qty))
	}
	if err := csv.iterator_last_error(r^); !csv.is_io_error(err, .EOF) {
		fmt.eprintln("csv error:", err)
		os.exit(1)
	}
	return result_from_map(m)
}
