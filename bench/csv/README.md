# Large CSV reader benchmark

A ~1 GB CSV aggregated by eleven readers, each adding one optimization to the
one before it, so every step's effect is measured on its own.

```sh
make bench          # build, generate data/sales.csv (15M rows, 957 MB), run all versions
make test           # correctness sweep (~650 files, every version)
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
Run-to-run noise is about ±5%.

| version | what it adds | best ms | GB/s | vs v0 | vs prev |
|---|---|---:|---:|---:|---:|
| v0_stdlib_stream | `core:encoding/csv` on a file stream, `strconv`, `map[string]` | 4216 | 0.23 | 1.0x | |
| v1_stdlib_memory | read the whole file first, same parser | 4674 | 0.20 | 0.90x | 0.90x |
| v2_scanner | hand-written byte loop; fields are slices into the buffer; only 3 columns kept | 2929 | 0.33 | 1.4x | 1.60x |
| v3_fast_numbers | parse cents and ints by hand instead of `strconv` | 2365 | 0.40 | 1.8x | 1.24x |
| v4_hash_table | open-addressing table instead of `map[string]` | 2106 | 0.45 | 2.0x | 1.12x |
| v5_no_bounds_check | `#no_bounds_check` on the scan loop | 1891 | 0.51 | 2.2x | 1.11x |
| v6_simd | classify 64 bytes at a time (bitmasks + prefix-XOR quote mask) | 1450 | 0.66 | 2.9x | 1.30x |
| v7_mmap | `mmap` the file instead of reading it into the heap | 910 | 1.05 | 4.6x | 1.59x |
| v8_field_index | write separator positions to an index; read columns at fixed offsets | 825 | 1.16 | 5.1x | 1.10x |
| v9_fast_hash | branch-free key: two in-place 8-byte words, 2-multiply hash | 602 | 1.59 | 7.0x | 1.37x |
| v10_threads | 4 threads, quote-parity-aware chunking, per-thread tables | **182** | **5.27** | **23x** | 3.31x |

Floors (the same file, doing only part of the work):

| floor | best ms | GB/s |
|---|---:|---:|
| `read_entire_file` into a fresh heap buffer | 509 | 1.88 |
| `mmap` + touch one byte per page | 5.5 | 173 |
| `mmap` + SIMD classification only, 1 thread | 150 | 6.4 |
| same, 4 threads | 42 | 23 |

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
- **v10 (3.3x on 4 cores):** a chunk can't simply start at the next newline,
  because quoted fields contain newlines. Each thread first counts quotes in
  its raw slice (SIMD popcount). The running parity says whether each cut
  point is inside quotes, and each chunk starts after the first newline
  outside quotes. That is correct for any RFC 4180 input, for one extra pass
  that costs ~40 ms across 4 threads.

## Where the rest of the time goes

Single-threaded, v9 runs at 1.6 GB/s against a 6.4 GB/s classification floor.
Per record, the main remaining cost is number parsing (~12 ns), which uses the
same kind of variable-length digit loops that hurt the key lookup. A
branch-free SWAR parse of the fixed `-?d+.dd` format is the obvious next step.

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
reader/v8_field_index.odin  v8 (two-stage scan, shared by v9/v10)
reader/v9_fast_hash.odin    v9
reader/v10_threads.odin     v10
test/run.sh, test/hostile.py  correctness sweep
```
