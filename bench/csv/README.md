# Large CSV reader benchmark

A ~1 GB CSV aggregated by thirteen readers, each adding one optimization to the
one before it, so every step's effect is measured on its own.

```sh
make bench          # build, generate data/sales.csv (15M rows, 957 MB), run all versions
make test           # correctness sweep (~650 files, every version)
sh test/run.sh v13  # the same sweep for some versions only
./bin/reader data/sales.csv -runs:3 v7 v8 floor   # run only some versions / floors
```

## The task

`gen` writes `id,ts,user_id,city,amount,qty,note` rows with RFC 4180 quoting:
cities and notes containing commas, escaped quotes (`""`), and newlines inside
quoted notes. Every reader computes, per city, the row count, `amount` summed in
integer cents, and the `qty` sum. While writing, `gen` tallies the
same totals into `sales.csv.expected`, and the harness checks every run against
it, so no version is graded against another parser.

## Results

15M rows, 957 MB, best of 7 runs, warm page cache. Machine: 4-core Xeon VM
(AVX-512), Linux. Odin `dev-2026-07`, `-o:speed -microarch:native`.
Run-to-run noise is about ±5-10%, and the VM's speed drifts between days, so
compare the ratios within one run rather than times across runs.

| version | what it adds | best ms | GB/s | vs v0 | vs prev |
|---|---|---:|---:|---:|---:|
| v0_stdlib_stream | `core:encoding/csv` on a file stream, `strconv`, `map[string]` | 4284 | 0.22 | 1.0x | |
| v1_stdlib_memory | read the whole file first, same parser | 4605 | 0.21 | 0.93x | 0.93x |
| v2_scanner | hand-written byte loop; fields are slices into the buffer; only 3 columns kept | 2815 | 0.34 | 1.5x | 1.64x |
| v3_fast_numbers | parse cents and ints by hand instead of `strconv` | 2293 | 0.42 | 1.9x | 1.23x |
| v4_hash_table | open-addressing table instead of `map[string]` | 2020 | 0.47 | 2.1x | 1.13x |
| v5_no_bounds_check | `#no_bounds_check` on the scan loop | 1899 | 0.50 | 2.3x | 1.06x |
| v6_simd | classify 64 bytes at a time (bitmasks + prefix-XOR quote mask) | 1409 | 0.68 | 3.0x | 1.35x |
| v7_mmap | `mmap` the file instead of reading it into the heap | 907 | 1.05 | 4.7x | 1.55x |
| v8_field_index | write separator positions to an index; read columns at fixed offsets | 846 | 1.13 | 5.1x | 1.07x |
| v9_fast_hash | branch-free key: two in-place 8-byte words, 2-multiply hash | 609 | 1.57 | 7.0x | 1.39x |
| v10_threads | 4 threads, quote-parity-aware chunking, per-thread tables | 199 | 4.80 | 21x | 3.05x |
| v11_tuned | prefetch 2 KB ahead + branch-free number parsing (found by profiling) | 173 | 5.53 | 25x | 1.15x |
| v12_speculative | guess chunk starts instead of a quote-counting pass; verify, redo if wrong | **157** | **6.10** | **27x** | 1.10x |

Floors (the same file, doing only part of the work):

| floor | best ms | GB/s |
|---|---:|---:|
| `read_entire_file` into a fresh heap buffer | 486 | 1.97 |
| `mmap` + touch one byte per page | 35 | 28 |
| `mmap` + SIMD classification only, 1 thread | 171 | 5.6 |
| same, 4 threads | 54 | 18 |

## What each step taught

- **v1 is slower than v0.** Reading 957 MB into a new heap buffer costs ~510 ms
  (page faults on fresh memory plus the copy out of the page cache, see
  `floor_read_file`). The stdlib parser was never waiting on I/O, so buffering
  everything first only adds that cost. The same 510 ms is what v7 gets back
  with `mmap`.
- **v2 (1.6x):** `core:encoding/csv` decodes runes, copies every field and
  builds a `[]string` for all 7 columns. A byte loop that slices only the 3
  needed columns skips most of that.
- **v3 (1.24x):** `strconv.parse_f64` is general-purpose. Amounts have two
  decimals, so parsing straight to integer cents is simpler, faster, and exact.
- **v4 and v5 (~1.1x each):** worthwhile but small. With 68 keys the map
  already lives in L1, and bounds checks are cheap next to branchy byte
  scanning.
- **v6 (1.3x):** the simdcsv technique. Compare 64 bytes against `"`, `,` and
  `\n` to get three bitmasks. A prefix XOR of the quote mask (6 shift-XORs)
  marks the bytes inside quotes, and `""` escapes cancel out by themselves.
  Field boundaries are the set bits of `(commas | newlines) & ~inside`, visited
  with `count_trailing_zeros`.
- **v7 (1.6x):** the largest single-thread step, and it touches no parsing
  code. Once parsing is fast, the heap copy is a third of the runtime.
- **v8 (1.1x), and finding the real bottleneck.** v8 removes the
  per-separator branches ("which column? end of record?"). Positions are
  written to an index buffer branch-free and read 7 per record. Each entry is
  tagged `pos<<1 | is_newline`, so one OR checks the column count. It helped
  less than expected, so I profiled v8 by removing one piece at a time:
  classification ~146 ms, indexing ~134 ms, number parsing ~186 ms, and the
  hash table lookup ~337 ms (22 ns per record).
- **v9 (1.37x):** the first attempt, a faster hash function alone, gained only
  5%. The cost was branch misprediction, not hashing. The FNV loop, the
  `memcmp` and any `if len < 8` run a data-dependent number of steps on
  random-length city names. v9 reads each key as two masked 8-byte words in
  place (loads may overlap; within 8 bytes of the buffer's ends it falls back
  to a copy), stores those words in the slot, and compares with three integer
  compares. Same work, almost no branches.
- **v10 (3.1x on 4 cores):** a chunk can't simply start at the next newline,
  because quoted fields contain newlines. Each thread first counts quotes in
  its raw slice (SIMD popcount). The running parity says whether each cut
  point is inside quotes, and each chunk starts after the first newline
  outside quotes. That is correct for any RFC 4180 input, for one extra pass
  over the file (v12 removes it).
- **v11 (1.15x; 1.38x single-threaded):** the two fixes profiling found, below.
  The step is smaller with 4 threads because part of the memory wait was
  already overlapped by the other cores, and the quote-counting pass, which
  the fixes don't touch, is a larger share of the total.
- **v12 (1.10x; 1.14x over 5 alternating rounds of v11 and v12):** no
  quote-counting pass. Each chunk starts after the first newline past its raw
  cut, as if that newline were outside quotes. That guess is wrong only when
  the cut lands in a field holding a quoted newline (about 1% of rows here).
  The scan already tracks quote state, so each chunk returns its quote parity
  for free; chaining the parities from the start of the file gives the true
  state at every guessed boundary. Chunks next to a wrong boundary are thrown
  away and the range between the real boundaries around them is scanned
  again, so the result is always exact. The scanner reports a malformed
  record instead of exiting, because a wrongly started chunk can look ragged.
  Removing the pass saved ~20 ms, less than the 4-thread classification
  floor (a comparable full pass over the file, ~50 ms), probably because the
  pass also faulted in the mapping and warmed caches for the main pass, which
  now pays that itself (not measured).
- **v13 (not in the table yet):** profiling v12 put number parsing on top
  (29% of core time): v11's parser ran its full 8-byte routine three times a
  row. v13 parses `amount` in one pass (drop the `.` from the loaded word,
  then all digits at once as cents) and reads `qty`'s 1-2 digits directly.
  Profiled over 10 runs, parsing CPU fell 23% and total CPU 9%, but parsing
  is still first (27%), now close to writing the separator index (25%). The
  rest of parsing is `amount`'s single chain of dependent steps. Its
  wall-clock gain over v12 has not been measured head to head yet.

## Profiling v9 to find v11

The VM exposes no hardware counters, so time came from `perf record -e
cpu-clock` (timer sampling, with `-debug` for line numbers), and branch
mispredictions from Valgrind's cachegrind simulator (`--branch-sim=yes`, on an
AVX2 build because Valgrind cannot run AVX-512).

1. **Waiting on memory.** 81% of the scan loop's samples sat on one
   instruction: the 64-byte load from the mapped file. The
   classification-only floor streams the same bytes in 150 ms, because its
   iterations are independent and the CPU keeps many loads in flight. v9 does
   index stores and record work between loads, so fewer are outstanding and
   memory latency shows. Prefetching 2 KB ahead took v9 from 615 to 533 ms
   (512 B to 4 KB all helped). `MAP_POPULATE` gained nothing, so page faults
   were not the cost.
2. **Branch mispredictions in number parsing.** cachegrind counted 2.35
   mispredicts per row: 1.02 in `amount`'s integer-digit loop and 0.49 in
   `qty`'s loop (1 or 2 digits, about 50/50), and only 0.04 in the hash table
   that v9 fixed. v11 parses with no loop: it loads the 8 bytes ending at
   the field, masks to the field's length, checks every byte is a digit, and
   combines the digits with three multiplies. Other formats (quoted, not 2
   decimals, more than 8 digits) fall back to the loop. 533 to 447 ms.
   (The simulator also flagged a 50/50 length check in `field`; reordering it
   measured within noise, so it isn't in v11.)

After both fixes v9's profile is flat: number parsing 27% (now straight-line
multiplies), writing the separator index 27%, record walk 15%, key lookup 13%,
SIMD classification 10%. No single hot spot is left; further gains would need
a different scan design.

## Limits

- v2 and later assume `\n` line endings. With `\r\n` the `\r` ends up in the
  last column, which this query doesn't read. The stdlib reader handles `\r\n`.
- v8 and later need every record to have exactly 7 fields and reject a ragged
  record, as `core:encoding/csv` does by default.
- `mmap` goes through `core:sys/posix` (Linux and macOS).
- All numbers are with the file already in the page cache. Cold-cache runs
  measure the disk instead.

## Gotcha found along the way

v10 first segfaulted on chunks starting at addresses that weren't 64-byte
aligned. In the single-threaded versions every block happened to be aligned,
because `mmap` returns page-aligned memory. The fault went away once
`intrinsics.unaligned_load(...)` was stored in a local before being passed by
value to a procedure. Passing it straight in seems to let the compiler fold it
into an aligned access. The code keeps the local, with a comment.

## Layout

```text
gen/gen.odin          data generator + expected totals
reader/main.odin      harness: runs, timing, checks, floors
reader/common.odin    result type, number parsing, hash table
reader/v0_stdlib.odin v0, v1
reader/v2_scanner.odin  v2-v5 (one scanner; the record sink varies)
reader/v6_simd.odin   v6, v7, mmap helper
reader/v8_field_index.odin  v8 (two-stage scan, shared by v9-v12)
reader/v9_fast_hash.odin    v9
reader/v10_threads.odin     v10
reader/v11_tuned.odin       v11
reader/v12_speculative.odin v12 (driver shared with v13)
reader/v13_fused_parse.odin v13
test/run.sh, test/hostile.py  correctness sweep
```
