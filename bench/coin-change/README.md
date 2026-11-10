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
| `cpp-gcc` (GCC 13.3) | 8-wide vector, store skipped when nothing changes | **89** | 964 |
| `zig` (0.17.1) | scalar, unrolled x4, branchless `cmov` + unconditional store | 255 | 964 |
| `rust-unchecked` | 32-wide vector, masked stores | 271 | 869 |
| `cpp-clang` (zig c++, clang 22.1.8) | 32-wide vector, masked stores | 330 | **847** |
| `cpp-clang-novec` | scalar, unrolled x2, compare-and-branch store | 388 | 859 |
| `rust` (1.97, safe indexing) | 32-wide vector, masked stores, bounds check in the scalar tail | 433 | 944 |
| `rust-novec` | scalar, not unrolled, one bounds check per iteration | 542 | 942 |

Means are over both run orders, 20 runs each. Run-to-run noise was about
±1-7%, so on the small-coin workload only the ~10% gap between the two groups
(`cpp-clang`, `cpp-clang-novec`, `rust-unchecked` vs the rest) is meaningful.

- **Large coins** (`186 419 83 408`, amount 10000, 20000 calls): which loop you
  get matters up to 6x. GCC wins by a wide margin.
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

**clang and rustc vectorize** 4 x 8 lanes with AVX-512 masked stores, guarded by
a runtime check that the coin is at least 32 elements away:

```asm
vpaddd    ymm2,ymm1,YMMWORD PTR [rax+r13*4-0x60]
vpcmpltud k1,ymm2,YMMWORD PTR [r11+r13*4-0x60]
vmovdqu32 YMMWORD PTR [r11+r13*4-0x60]{k1},ymm2
```

That vector loop is *slower* than Zig's scalar one on this machine. `-novec`
confirms vectorizing only buys clang ~15% here.

**GCC vectorizes 8-wide and tests the mask first** (`kortestb k1,k1` then a
jump), so it only stores when some lane improved. Most iterations improve
nothing, which is the likely reason it is 3x faster than everything else. I did
not profile to confirm the cause.

**Safe Rust keeps a bounds check.** LLVM hoists it out of the vector loop, but
a `cmp`+`jae <panic>` pair stays in the scalar tail and in `rust-novec`.
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
  scaling. The ranking of vector vs scalar loops is likely to change on CPUs
  without AVX-512 or with different store-forwarding behaviour.
- One input size. At amount 10000 the table is 40 KB and fits in L1/L2.
- Process startup is included in every time; it is under 1 ms against 90-960 ms.
- Compiler versions: Zig 0.17.1, rustc 1.97.0, clang 22.1.8 (bundled with Zig),
  GCC 13.3.0, hyperfine 2.0.0.
