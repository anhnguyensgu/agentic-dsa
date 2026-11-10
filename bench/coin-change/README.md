# Coin Change (LeetCode 322) in Zig, Rust and C++

The same bottom-up DP in three languages, benchmarked with hyperfine, with the
generated assembly compared.

```text
coin_change.zig  coin_change.rs  coin_change.cpp   the three implementations
build.sh    builds every variant into bin/ and disassembles coin_change() into asm/
bench.sh    checks all outputs agree, then runs hyperfine
asm/        disassembly of coin_change() from each benchmarked binary
results/    hyperfine tables from the run reported below
```

```sh
./build.sh && ./bench.sh
```

## Short answer

**The assembly is not the same**, even though Zig, Rust and C++ (clang) all use
LLVM 22 here and the source is line-for-line equivalent. The inner loop comes
out in four different shapes, and the timings follow the shape, not the
language:

| Build | Inner loop it got | large coins, mean ms | small coins, mean ms |
|:---|:---|---:|---:|
| `cpp-gcc` (GCC 13.3) | 8-wide vector loop, used whenever coin >= 8 | **89** | 964 |
| `zig` (0.17.1) | scalar, unrolled x4, branchless `cmov` + unconditional store | 255 | 964 |
| `rust-unchecked` | has a 32-wide vector loop, but runs its scalar fallback here | 271 | 869 |
| `cpp-clang` (zig c++, clang 22.1.8) | has a 32-wide vector loop, but runs its scalar fallback here | 330 | **847** |
| `cpp-clang-novec` | scalar, unrolled x2, compare-and-branch store | 388 | 859 |
| `rust` (1.97, safe indexing) | as `rust-unchecked`, with a bounds check in the scalar fallback | 433 | 944 |
| `rust-novec` | scalar, not unrolled, one bounds check per iteration | 542 | 942 |

Means are over both run orders, 20 runs each. Run-to-run noise was about
±1-7%, so on the small-coin workload only the ~10% gap between the two groups
(`cpp-clang`, `cpp-clang-novec`, `rust-unchecked` vs the rest) is meaningful.

- **Large coins** (`186 419 83 408`, amount 10000, 20000 calls): which loop
  actually runs matters up to 6x. GCC wins by a wide margin because it is the
  only build executing vector code on this input (see below).
- **Small coins** (`1 2 5 10 20 25`): every coin is closer than one vector
  width, so every build runs scalar code and they land within ~13% of each
  other.

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

## Fairness

- **Same algorithm and types**: `u32` table, wrapping `+ 1`, `usize` indices,
  coin-outer / amount-inner loop, exclusive upper bound. An earlier draft used
  `c..=amount` in Rust; inclusive ranges block vectorization, so all three use
  `a < len`.
- **Same backend where possible**: C++ is built with `zig c++`, so Zig and C++
  share LLVM 22.1.8; rustc 1.97 ships LLVM 22.1.6. GCC is a reference point only.
- **Same flags**: `-O3` / `opt-level=3` / `ReleaseFast`, host CPU on all
  (`-march=native`, `target-cpu=native`, `-mcpu=native`), no unwinding,
  `panic=abort`, one codegen unit.
- **Same allocator and libc**: one `malloc`/`free` per call from the system
  glibc in all three. Zig calls libc directly instead of using its own
  allocator and startup code.
- **Nothing computed at compile time**: coins, amount and repetition count come
  from `argv`, the amount varies per call, and `coin_change` is not inlined
  (checked: each binary has exactly one `call <coin_change>`). Zig needed
  `@call(.never_inline, ...)`; without it the kernel was inlined into `main`.
- **Same measurement**: `hyperfine -N` (no shell), pinned to one core with
  `taskset`, 5 warmups, 20 runs, identical arguments, outputs verified equal
  across all binaries before timing, and each workload timed in forward and
  reverse order. The two orders agree within noise.

What is *not* equal, and cannot be made equal from source: safe Rust checks
bounds (hence `rust-unchecked`), and Zig does not auto-vectorize (hence the
`-novec` builds).

## Caveats

- One machine: a 4-vCPU cloud VM, Intel Xeon @ 2.30GHz with AVX-512 (LLVM
  detects it as `graniterapids`). Shared hardware, no control over frequency
  scaling. Absolute numbers and gaps are likely to differ on CPUs
  without AVX-512.
- One amount and two coin sets in the main table. As the section above shows,
  the ranking flips with the coin values, so do not read it as a general
  ordering. At amount 10000 the table is 40 KB and fits in L1/L2.
- Process startup is included in every time; it is under 1 ms against 90-960 ms.
- Compiler versions: Zig 0.17.1, rustc 1.97.0, clang 22.1.8 (bundled with Zig),
  GCC 13.3.0, hyperfine 2.0.0.
