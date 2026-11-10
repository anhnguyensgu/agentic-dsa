#!/bin/sh
# Benchmarks every binary in ./bin with hyperfine on two workloads.
#   large: every coin is >= 32, so the vectorized loop (where one exists) runs
#   small: every coin is <  32, so the dependence distance forces scalar code
# Fairness: one pinned core, no shell (-N), warmup runs, identical arguments,
# outputs checked equal first, and each workload measured in both orders so a
# drifting machine cannot favour whoever runs first.
set -eu
cd "$(dirname "$0")"
CORE=${CORE:-2}
RUNS=${RUNS:-20}
ORDER="zig zig-simd cpp-clang rust rust-unchecked cpp-clang-novec rust-novec cpp-gcc"
REVERSED="cpp-gcc rust-novec cpp-clang-novec rust-unchecked rust cpp-clang zig-simd zig"
# The Odin binaries exist only if odin was installed when build.sh ran.
for b in odin odin-unchecked; do
    [ -x "bin/$b" ] && ORDER="$ORDER $b" && REVERSED="$b $REVERSED"
done
mkdir -p results

run() { # name, order, args...
    name=$1 order=$2; shift 2
    set -- "$@"
    cmds=""
    for b in $order; do cmds="$cmds -n $b 'bin/$b $*'"; done
    eval taskset -c "$CORE" hyperfine -N --warmup 5 --runs "$RUNS" \
        --export-json "results/$name.json" --export-markdown "results/$name.md" $cmds
}

check() { # args...
    want=$(bin/zig "$@")
    for b in $ORDER; do
        got=$(bin/$b "$@")
        [ "$got" = "$want" ] || { echo "MISMATCH $b: $got != $want ($*)"; exit 1; }
    done
    echo "outputs agree: $want  ($*)"
}

LARGE="20000 10000 186 419 83 408"
SMALL="20000 10000 1 2 5 10 20 25"

check 1 11 1 2 5
check 1 3 2
check 1 0 1
check 1 6249 186 419 83 408
check $LARGE
check $SMALL

run large         "$ORDER"    $LARGE
run large-reverse "$REVERSED" $LARGE
run small         "$ORDER"    $SMALL
run small-reverse "$REVERSED" $SMALL
