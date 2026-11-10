# Coin Change (LeetCode 322) in Zig, Rust, C++ and Odin

The same bottom-up DP in four languages, benchmarked with hyperfine, with the
generated assembly compared.

```text
coin_change.zig  coin_change.rs  coin_change.cpp  coin_change.odin   the implementations
coin_change_simd.zig   Zig again, inner loop vectorized by hand with @Vector
build.sh    builds every variant into bin/ and disassembles coin_change() into asm/
bench.sh    checks all outputs agree, then runs hyperfine
asm/        disassembly of coin_change() from each benchmarked binary
results/    hyperfine tables from the run reported below
```

```sh
./build.sh && ./bench.sh
```

## Short answer

**The assembly is not the same**, even though Zig, Rust, Odin and C++ (clang)
all use LLVM 22 here and the source is equivalent. The inner loop comes out in
several different shapes, and the timings follow the shape, not the language:

| Build | Inner loop it got | large coins, mean ms | small coins, mean ms |
|:---|:---|---:|---:|
| `zig-simd` (hand-written `@Vector`) | 8-wide vector loop, used whenever coin >= 8 | **128** | 1474 |
| `cpp-gcc` (GCC 13.3) | 8-wide vector loop, used whenever coin >= 8 | 147 | 1374 |
| `odin-unchecked` | has a 32-wide vector loop, but runs its scalar fallback here | 325 | **1153** |
| `rust-unchecked` | has a 32-wide vector loop, but runs its scalar fallback here | 376 | 1183 |
| `zig` (0.17.1) | scalar, unrolled x4, branchless `cmov` + unconditional store | 400 | 1335 |
| `cpp-clang` (zig c++, clang 22.1.8) | has a 32-wide vector loop, but runs its scalar fallback here | 477 | 1175 |
| `rust` (1.97, safe indexing) | as `rust-unchecked`, with a bounds check in the scalar fallback | 579 | 1455 |
| `cpp-clang-novec` | scalar, unrolled x2, compare-and-branch store | 602 | 1216 |
| `rust-novec` | scalar, not unrolled, one bounds check per iteration | 733 | 1476 |
| `odin` (dev-2026-11, bounds checks on) | as `odin-unchecked`, with two bounds checks in the scalar fallback | 867 | 1691 |

Means are over both run orders, 20 runs each, all ten binaries in one session.
`zig-simd` is the only row whose source differs from the others: its inner
loop is vectorized by hand. Every other row is the same plain loop.

Noise: standard deviations were 2-5% on small coins but up to 24% on large
coins, so on large coins treat gaps under about 15% as ties. That covers
`zig-simd` / `cpp-gcc`, and `odin-unchecked` / `rust-unchecked` / `zig`.

The host has been about 1.5x slower since the first session, when the same
binaries (without Odin or `zig-simd`) measured GCC 89, Zig 255, rust-unchecked
271, clang 330, clang-novec 388, rust 433, rust-novec 542 ms on large coins.
The order of the groups is the same; only compare numbers within one run.

- **Large coins** (`186 419 83 408`, amount 10000, 20000 calls): which loop
  actually runs matters up to 6x. GCC wins by a wide margin because it is the
  only build executing vector code on this input (see below).
- **Small coins** (`1 2 5 10 20 25`): every coin is closer than one vector
  width, so every build runs scalar code. The unchecked builds land within
  ~20% of each other; the bounds-checked ones trail.

No language is "the fast one". The spread comes from optimizer decisions.

## What differs in the assembly

All excerpts are from `asm/*.s`.

**Zig does not vectorize.** Its loop is scalar and branchless:

```asm
mov    r10d,DWORD PTR [r9+rdi*1-0xc]   ; dp[a-c]
inc    r10d
mov    r11d,DWORD PTR [r9-0xc]         ; dp[a]
cmp    r10d,r11d
cmovae r10d,r11d                       ; min
mov    DWORD PTR [r9-0xc],r10d         ; always store
```

Zig 0.17.1 produced no vector instructions for this loop in any form I tried
(wrapping arithmetic, `@min`, separate source/destination pointers), nor for a
trivial `p[i] = q[i] + 1` loop, while the clang inside the same Zig
distribution vectorizes the C++ version. The `@memset` fill is scalar too. So
this is the Zig front end's pipeline, not the source.

**Zig matches GCC once the vector step is written by hand.**
`coin_change_simd.zig` replaces the inner loop with an explicit
`@Vector(8, u32)` step behind a `coin >= 8` test, the same distance guard GCC
derives automatically. It compiles to `vpsubd` / `vpminud` / plain `vmovdqu`
(`asm/zig-simd.s`) and is 3x faster than plain Zig on large coins, level with
GCC. On small coins it is about 10% slower than plain Zig; coins 10, 20 and 25
now take the vector path there, and I have not checked why that costs time.
With coins above half the amount it reaches ~71 ms, behind clang's 32-wide
loop at ~23 ms, because it handles 8 elements per step with no interleaving.

**clang and rustc vectorize, but guard the vector loop with a check that
almost never passes.** They emit 4 x 8 lanes with AVX-512 masked stores:

```asm
vpaddd    ymm2,ymm1,YMMWORD PTR [rax+r13*4-0x60]
vpcmpltud k1,ymm2,YMMWORD PTR [r11+r13*4-0x60]
vmovdqu32 YMMWORD PTR [r11+r13*4-0x60]{k1},ymm2
```

The loop reads `dp[a-c]` and writes `dp[a]` in the same array. LLVM's runtime
guard asks whether the whole read range and the whole write range overlap, and
they do unless `coin > amount / 2`. So for `186 419 83 408` the vector loop is
never entered and the scalar fallback runs. That is why `cpp-clang` is barely
faster than `cpp-clang-novec`.

**GCC guards on the distance instead** (`lea rax,[rcx-0x4]; cmp rax,0x18`): it
takes its 8-wide vector loop whenever the coin is at least 8 elements away,
which is all that correctness needs. That is the whole reason it is ~3x faster.

Measured to confirm (amount 10000, 20000 calls, 10 runs, same machine):

| Coins | gcc | clang | rust-unchecked | zig |
|:---|---:|---:|---:|---:|
| `4003 4507 4801 4999` (all just under half) | 62 ms | 186 ms | 130 ms | 230 ms |
| `5003 6007 7001 8009` (all over half) | 49 ms | **23 ms** | 42 ms | 151 ms |

Once clang's guard passes, its wider loop is about 2x faster than GCC's.
GCC also tests the mask and skips the store when no lane improved, but that is
not what makes it fast: a hand-written 8-wide loop that always does the masked
store ran at the same speed as GCC's.

**Safe Rust keeps a bounds check.** LLVM hoists it out of the vector loop, but
a `cmp`+`jae <panic>` pair stays in the scalar fallback, which is the code that
runs here, and in `rust-novec`.
Dropping it with `get_unchecked` (`rust-unchecked`) takes the large-coin time
from 433 ms to 271 ms. On small coins the check costs about 8%.

**Scalar loops differ too.** With vectorization off: Zig unrolls x4 with `cmov`,
clang unrolls x2 with a conditional store, rustc does not unroll. Branchless is
better when updates are unpredictable (large coins) and no better when they are
predictable (small coins).

## Odin

`coin_change.odin` is the same algorithm in idiomatic Odin: `make` / `delete`
on Odin's default allocator, `core:os`, `core:strconv` and `core:fmt`, with no
direct libc calls. It is built twice: `odin` (default, bounds checks on) and
`odin-unchecked` (`-no-bounds-check`). `build.sh` / `bench.sh` include both
only when `odin` is on `PATH`.

**Odin gets the same code as clang and rustc.** Its optimizer pipeline runs
LLVM's loop vectorizer (unlike Zig 0.17), and `asm/odin.s` shows the identical
4 x 8-lane masked-store loop behind the identical range-overlap guard. So on
the benchmark coins it also runs its scalar fallback, and it flips the same
way when the coins cross `amount / 2` (same setup as the table above, 10 runs):

| Coins | gcc | clang | rust-unchecked | odin-unchecked | odin | zig |
|:---|---:|---:|---:|---:|---:|---:|
| `4003 4507 4801 4999` | 69 ms | 188 ms | 127 ms | 156 ms | 378 ms | 260 ms |
| `5003 6007 7001 8009` | 54 ms | **24 ms** | 29 ms | 42 ms | 54 ms | 160 ms |

**Bounds checks cost Odin more than Rust here.** The scalar fallback keeps two
checks per iteration (`cmp rax,r15; jae` and `cmp r8,r11; je`, both to
`bounds_check_error`), where Rust keeps one. With checks on, Odin is the
slowest build on both workloads (867 ms); with `-no-bounds-check` it is in the
fastest auto-vectorizing LLVM group (325 ms).

**Allocation differs slightly.** Odin's `make` returns zeroed memory, so the
table is written twice per call (zero, then fill with the sentinel) where the
others write it once, and the call goes through the allocator procedure in
`context` (`runtime::mem_alloc_bytes`) rather than straight to `malloc`. On
Linux that allocator still ends up in glibc. This is the price of using Odin's
own allocator and is included in Odin's times.

## Fairness

- **Same algorithm and types**: `u32` table, wrapping `+ 1`, `usize` indices,
  coin-outer / amount-inner loop, exclusive upper bound. An earlier draft used
  `c..=amount` in Rust; inclusive ranges block vectorization, so all four use
  `a < len`.
- **Same backend where possible**: C++ is built with `zig c++`, so Zig and C++
  share LLVM 22.1.8; Odin was built against LLVM 22.1.8 too; rustc 1.97 ships
  LLVM 22.1.6. GCC is a reference point only.
- **Same flags**: `-O3` / `opt-level=3` / `ReleaseFast`, host CPU on all
  (`-march=native`, `target-cpu=native`, `-mcpu=native`), no unwinding,
  `panic=abort`, one codegen unit.
- **Same allocator and libc**: one `malloc`/`free` per call from the system
  glibc in Zig, Rust and C++. Zig calls libc directly instead of using its own
  allocator and startup code. Odin deliberately uses its own allocator; see
  the Odin section.
- **Nothing computed at compile time**: coins, amount and repetition count come
  from `argv`, the amount varies per call, and `coin_change` is not inlined
  (checked: each binary has exactly one `call <coin_change>`). Zig needed
  `@call(.never_inline, ...)`; without it the kernel was inlined into `main`.
- **Same measurement**: `hyperfine -N` (no shell), pinned to one core with
  `taskset`, 5 warmups, 20 runs, identical arguments, outputs verified equal
  across all binaries before timing, and each workload timed in forward and
  reverse order. The two orders agree within noise.

What is *not* equal, and cannot be made equal from source: safe Rust and
default Odin check bounds (hence the `-unchecked` builds), Zig does not
auto-vectorize (hence the `-novec` builds), and Odin uses its own allocator
interface and I/O packages where the others call glibc directly.

## Caveats

- One machine: a 4-vCPU cloud VM, Intel Xeon @ 2.30GHz with AVX-512 (LLVM
  detects it as `graniterapids`). Shared hardware, no control over frequency
  scaling. Absolute numbers and gaps are likely to differ on CPUs
  without AVX-512.
- One amount and two coin sets in the main table. As the section above shows,
  the ranking flips with the coin values, so do not read it as a general
  ordering. At amount 10000 the table is 40 KB and fits in L1/L2.
- Process startup is included in every time; it is about 1 ms against 150-1700 ms.
- Compiler versions: Zig 0.17.1, rustc 1.97.0, clang 22.1.8 (bundled with Zig),
  Odin dev-2026-11 (commit 85afcb3, built from source against LLVM 22.1.8 from
  apt.llvm.org), GCC 13.3.0, hyperfine 2.0.0.
