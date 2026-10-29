// Benchmarks a ladder of CSV readers, each adding one optimization to the one
// before, on the file made by ../gen. Every run is checked against the
// generator's `.expected` totals.
//
//   reader <file.csv> [-runs:N] [version-name-prefix ...]
package csvbench

import "core:fmt"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:time"

Version :: struct {
	name: string,
	run:  proc(path: string) -> Result,
}

VERSIONS := [?]Version {
	{"v0_stdlib_stream", v0_stdlib_stream},
	{"v1_stdlib_memory", v1_stdlib_memory},
	{"v2_scanner", v2_scanner},
	{"v3_fast_numbers", v3_fast_numbers},
	{"v4_hash_table", v4_hash_table},
	{"v5_no_bounds_check", v5_no_bounds_check},
	{"v6_simd", v6_simd},
	{"v7_mmap", v7_mmap},
	{"v8_field_index", v8_field_index},
	{"v9_fast_hash", v9_fast_hash},
	{"v10_threads", v10_threads},
}

main :: proc() {
	path := ""
	runs := 5
	filters: [dynamic]string
	for arg in os.args[1:] {
		if strings.has_prefix(arg, "-runs:") {
			ok: bool
			runs, ok = strconv.parse_int(arg[len("-runs:"):])
			if !ok || runs < 1 {usage()}
		} else if path == "" {
			path = arg
		} else {
			append(&filters, arg)
		}
	}
	if path == "" {usage()}

	expected := string(read_file(strings.concatenate({path, ".expected"})))
	info, serr := os.stat(path, context.allocator)
	if serr != nil {
		fmt.eprintln("cannot stat", path, serr)
		os.exit(1)
	}
	size := info.size
	fmt.printfln("%s: %.1f MB, best and median of %d runs, warm page cache\n", path, f64(size) / 1e6, runs)
	fmt.printfln("%-20s %10s %10s %8s %9s %9s  %s", "version", "best ms", "median ms", "GB/s", "vs v0", "vs prev", "check")

	first_best, prev_best: f64
	all_ok := true
	for v in VERSIONS {
		if len(filters) > 0 {
			selected := false
			for f in filters {if strings.has_prefix(v.name, f) {selected = true}}
			if !selected {continue}
		}
		times := make([]f64, runs)
		defer delete(times)
		ok := true
		for r in 0 ..< runs {
			start := time.tick_now()
			res := v.run(path)
			times[r] = time.duration_milliseconds(time.tick_since(start))
			got := result_format(res)
			if got != expected {
				ok = false
				if r == 0 {fmt.eprintfln("%s: wrong result\n--- got\n%s--- want\n%s", v.name, got, expected)}
			}
			delete(got)
			result_destroy(res)
			free_all(context.temp_allocator)
		}
		slice.sort(times)
		best, median := times[0], times[runs / 2]
		if first_best == 0 {first_best = best}
		if prev_best == 0 {prev_best = best}
		fmt.printfln(
			"%-20s %10s %10s %8s %9s %9s  %s",
			v.name,
			fmt.tprintf("%.1f", best),
			fmt.tprintf("%.1f", median),
			fmt.tprintf("%.2f", f64(size) / (best * 1e6)),
			fmt.tprintf("%.2fx", first_best / best),
			fmt.tprintf("%.2fx", prev_best / best),
			ok ? "ok" : "WRONG",
		)
		prev_best = best
		all_ok &&= ok
	}

	// Lower bounds: what parts of the work cost on their own, with no parsing.
	fmt.printfln("\n%-20s %10s %10s %8s", "floor", "best ms", "median ms", "GB/s")
	for fl in FLOORS {
		if len(filters) > 0 {
			selected := false
			for f in filters {if strings.has_prefix(fl.name, f) {selected = true}}
			if !selected {continue}
		}
		times := make([]f64, runs)
		defer delete(times)
		for r in 0 ..< runs {
			start := time.tick_now()
			floor_sink += fl.run(path)
			times[r] = time.duration_milliseconds(time.tick_since(start))
		}
		slice.sort(times)
		fmt.printfln(
			"%-20s %10s %10s %8s",
			fl.name,
			fmt.tprintf("%.1f", times[0]),
			fmt.tprintf("%.1f", times[runs / 2]),
			fmt.tprintf("%.2f", f64(size) / (times[0] * 1e6)),
		)
	}
	if !all_ok {os.exit(1)}
}

Floor :: struct {
	name: string,
	run:  proc(path: string) -> int,
}

FLOORS := [?]Floor {
	{"floor_read_file", floor_read_file},
	{"floor_mmap_touch", floor_mmap_touch},
	{"floor_simd_classify", floor_simd_classify},
	{"floor_simd_classify_mt", floor_simd_classify_mt},
}

floor_sink: int // keeps the floors' work observable

// read_entire_file into a fresh heap buffer, then free it.
floor_read_file :: proc(path: string) -> int {
	data := read_file(path)
	defer delete(data)
	return int(data[len(data) / 2])
}

// mmap and fault in every page by reading one byte from each.
floor_mmap_touch :: proc(path: string) -> int {
	data := map_file(path)
	defer unmap_file(data)
	sum := 0
	for i := 0; i < len(data); i += 4096 {sum += int(data[i])}
	return sum
}

// mmap + the 64-byte structural classification, counting separators
// instead of visiting fields: the cost of v7 without the per-field work.
floor_simd_classify :: proc(path: string) -> int {
	data := map_file(path)
	defer unmap_file(data)
	return count_separators(data)
}

// Same, split across threads (raw cuts; the count is approximate, the time is not).
floor_simd_classify_mt :: proc(path: string) -> int {
	data := map_file(path)
	defer unmap_file(data)
	chunks := make([]Chunk, max(1, os.get_processor_core_count()))
	defer delete(chunks)
	for &c, k in chunks {
		c.data = data
		c.lo = k * len(data) / len(chunks)
		c.hi = (k + 1) * len(data) / len(chunks)
	}
	run_all(chunks, proc(c: ^Chunk) {c.quotes = count_separators(c.data[c.lo:c.hi])})
	total := 0
	for c in chunks {total += c.quotes}
	return total
}

usage :: proc() -> ! {
	fmt.eprintln("usage: reader <file.csv> [-runs:N] [version-name-prefix ...]")
	os.exit(2)
}
