#!/bin/sh
# Builds every variant into ./bin and disassembles coin_change() into ./asm.
# Same settings everywhere: max optimisation, host CPU, glibc malloc,
# dynamically linked glibc, no unwinding.
set -eu
cd "$(dirname "$0")"
rm -rf bin asm
mkdir -p bin asm

CXXFLAGS="-std=c++20 -O3 -march=native -fno-exceptions -fno-rtti -fno-asynchronous-unwind-tables"
RSFLAGS="--edition 2021 -C opt-level=3 -C target-cpu=native -C codegen-units=1 -C panic=abort -C force-unwind-tables=no"
ZIGFLAGS="-O ReleaseFast -mcpu=native -lc -fno-unwind-tables"

# The three LLVM builds. C++ uses the clang bundled with zig, so Zig and C++
# share one LLVM (22.1.8); rustc 1.97 ships LLVM 22.1.6.
zig build-exe $ZIGFLAGS coin_change.zig -femit-bin=bin/zig
# Zig with the inner loop vectorized by hand; not like-for-like source.
zig build-exe $ZIGFLAGS coin_change_simd.zig -femit-bin=bin/zig-simd
zig c++ $CXXFLAGS coin_change.cpp -o bin/cpp-clang
rustc $RSFLAGS coin_change.rs -o bin/rust
# Rust without bounds checks, matching C++ operator[] and Zig ReleaseFast.
rustc $RSFLAGS --cfg unchecked coin_change.rs -o bin/rust-unchecked

# Zig 0.17.1 does not auto-vectorize; these two turn the vectorizers off in
# clang and rustc as well, to compare the scalar code like for like.
zig c++ $CXXFLAGS -fno-vectorize -fno-slp-vectorize coin_change.cpp -o bin/cpp-clang-novec
rustc $RSFLAGS -C no-vectorize-loops -C no-vectorize-slp coin_change.rs -o bin/rust-novec

# C++ with GCC: a different backend, kept as a reference point.
g++ $CXXFLAGS coin_change.cpp -o bin/cpp-gcc

# Odin, only when the compiler is installed. Bounds checks are on by default
# (like safe Rust), so it is built both ways.
if command -v odin >/dev/null 2>&1; then
    ODINFLAGS="-file -o:aggressive -microarch:native"
    odin build coin_change.odin $ODINFLAGS -out:bin/odin
    odin build coin_change.odin $ODINFLAGS -no-bounds-check -out:bin/odin-unchecked
else
    echo "odin not found: skipping the Odin builds"
fi

# Accumulator form (coin_change_acc.*): loops swapped so each amount reduces
# over the coins into a register and stores once. Same flags as above.
zig build-exe $ZIGFLAGS coin_change_acc.zig -femit-bin=bin/zig-acc
zig c++ $CXXFLAGS coin_change_acc.cpp -o bin/cpp-clang-acc
g++ $CXXFLAGS coin_change_acc.cpp -o bin/cpp-gcc-acc
rustc $RSFLAGS coin_change_acc.rs -o bin/rust-acc
rustc $RSFLAGS --cfg unchecked coin_change_acc.rs -o bin/rust-unchecked-acc
if command -v odin >/dev/null 2>&1; then
    odin build coin_change_acc.odin $ODINFLAGS -out:bin/odin-acc
    odin build coin_change_acc.odin $ODINFLAGS -no-bounds-check -out:bin/odin-unchecked-acc
fi

# Multiple accumulators (coin_change_multi.*): the accumulator form with the
# reduction over coins unrolled into four independent running minimums.
zig build-exe $ZIGFLAGS coin_change_multi.zig -femit-bin=bin/zig-multi
zig c++ $CXXFLAGS coin_change_multi.cpp -o bin/cpp-clang-multi
g++ $CXXFLAGS coin_change_multi.cpp -o bin/cpp-gcc-multi
rustc $RSFLAGS coin_change_multi.rs -o bin/rust-multi
rustc $RSFLAGS --cfg unchecked coin_change_multi.rs -o bin/rust-unchecked-multi
if command -v odin >/dev/null 2>&1; then
    odin build coin_change_multi.odin $ODINFLAGS -out:bin/odin-multi
    odin build coin_change_multi.odin $ODINFLAGS -no-bounds-check -out:bin/odin-unchecked-multi
fi
rm -f bin/*.o

# Disassemble from the binaries that get benchmarked, one instruction per
# line, without addresses, so the files diff cleanly.
for b in bin/*; do
    objdump -d --no-show-raw-insn --no-addresses -M intel --disassemble=coin_change "$b" |
        sed -n '/<coin_change>:/,$p' | sed 's/[[:space:]]*#.*$//; s/[[:space:]]*$//; /^$/d; /^Disassembly/d' \
        > "asm/$(basename "$b").s"
done
wc -l asm/*.s
