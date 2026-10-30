#!/bin/sh
# Correctness sweep for every reader version. Each case compares against an
# `.expected` file written by the generator or by Python's csv module.
#   - generator output at many small sizes, so thread cuts land everywhere
#   - the same files without their trailing newline
#   - quote-heavy files with newlines, commas and "" inside fields
#   - files of long multi-line quoted notes (v12's wrong-guess path)
#   - a ragged file, which the record-indexing versions must reject
#
#   sh test/run.sh            every version
#   sh test/run.sh v12 v13    only versions whose names start with these
set -eu
only="$*"
cd "$(dirname "$0")/.."
dir=data/test
mkdir -p "$dir"
fail=0

check() { # file
	# shellcheck disable=SC2086 # $only is a list of version prefixes
	if ! ./bin/reader "$1" -runs:1 $only >/dev/null 2>&1; then
		echo "FAIL: $1 ${only:-(all versions)}"
		fail=1
	fi
}

for rows in $(seq 0 300) 1000 4099 20000; do
	./bin/gen "$dir/g.csv" "$rows" >/dev/null
	check "$dir/g.csv"
	if [ "$rows" -gt 0 ]; then
		head -c -1 "$dir/g.csv" >"$dir/gn.csv"
		cp "$dir/g.csv.expected" "$dir/gn.csv.expected"
		check "$dir/gn.csv"
	fi
done

for rows in 1 2 3 4 5 8 13 21 50 99 500 5000 20000; do
	python3 -I test/hostile.py "$dir/h.csv" "$rows"
	check "$dir/h.csv"
	head -c -1 "$dir/h.csv" >"$dir/hn.csv"
	cp "$dir/h.csv.expected" "$dir/hn.csv.expected"
	check "$dir/hn.csv"
done

# Notes made of many quoted lines: most of v12's guessed cuts land inside
# quotes, so its redo path runs (all of its chunks, or only some of them).
for rows in 1 3 13 55 400 2000; do
	python3 -I test/hostile.py "$dir/l.csv" "$rows" long
	check "$dir/l.csv"
done

# Number formats at the edges of v11/v13's branch-free parsers: 8-byte
# amounts, a sign, no whole part, 3-digit qty, and ones they hand back.
printf 'id,ts,user_id,city,amount,qty,note\n1,t,u,Oslo,1.5,7,x\n2,t,u,Oslo,12,"7",x\n3,t,u,Oslo,"3.25",10,x\n4,t,u,Oslo,123456789.01,1,x\n5,t,u,Oslo,-0.05,20,x\n6,t,u,Oslo,99999.99,100,x\n7,t,u,Oslo,-9999.99,3,x\n8,t,u,Oslo,-.50,1,x\n' >"$dir/numbers.csv"
printf 'Oslo\t8\t12354680521\t149\n' >"$dir/numbers.csv.expected"
check "$dir/numbers.csv"

printf 'id,ts,user_id,city,amount,qty,note\n1,t,u,Oslo,1.00,2,x\n2,t,u,Oslo,1.00,2\n' >"$dir/ragged.csv"
printf 'Oslo\t2\t200\t4\n' >"$dir/ragged.csv.expected"
for v in ${only:-v8 v9 v10 v11 v12 v13}; do
	if ./bin/reader "$dir/ragged.csv" -runs:1 "$v" 2>&1 | grep -q "does not have 7 fields"; then :; else
		echo "FAIL: $v accepted a ragged record"
		fail=1
	fi
done

rm -rf "$dir"
[ "$fail" -eq 0 ] && echo "correct: ${only:-all versions}"
exit "$fail"
