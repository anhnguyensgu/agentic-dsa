#!/bin/sh
# Correctness sweep for every reader version. Each case compares against an
# `.expected` file written by the generator or by Python's csv module.
#   - generator output at many small sizes, so thread cuts land everywhere
#   - the same files without their trailing newline
#   - quote-heavy files with newlines, commas and "" inside fields
#   - a ragged file, which the record-indexing versions must reject
set -eu
cd "$(dirname "$0")/.."
dir=data/test
mkdir -p "$dir"
fail=0

check() { # file [versions...]
	if ! ./bin/reader "$@" -runs:1 >/dev/null 2>&1; then
		echo "FAIL: $*"
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

printf 'id,ts,user_id,city,amount,qty,note\n1,t,u,Oslo,1.00,2,x\n2,t,u,Oslo,1.00,2\n' >"$dir/ragged.csv"
printf 'Oslo\t2\t200\t4\n' >"$dir/ragged.csv.expected"
for v in v8 v9 v10; do
	if ./bin/reader "$dir/ragged.csv" -runs:1 "$v" 2>&1 | grep -q "does not have 7 fields"; then :; else
		echo "FAIL: $v accepted a ragged record"
		fail=1
	fi
done

rm -rf "$dir"
[ "$fail" -eq 0 ] && echo "all reader versions correct"
exit "$fail"
