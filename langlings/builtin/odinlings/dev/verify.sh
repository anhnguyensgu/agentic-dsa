#!/bin/sh
# Checks the course itself, not your answers: every solution must pass, and
# every exercise must fail as shipped unless it is identical to its solution
# (intro1 is meant to pass). It copies the course into a temporary workspace
# and runs `langlings verify` there, so the commands and output matching are
# exactly the ones in track.toml and your progress is untouched.
set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
track="$here/track.toml"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# Use the installed runner, or build the one next to the course.
runner=$(command -v langlings || true)
if [ -z "$runner" ]; then
	runner="$tmp/langlings"
	(cd "$here/../.." && go build -o "$runner" .)
fi

# setup DIR SRC: a workspace in DIR whose exercises/ folder is a copy of SRC.
setup() {
	mkdir -p "$1/tracks" "$1/odinlings"
	cp "$track" "$1/tracks/odinlings.toml"
	cp -R "$2" "$1/odinlings/exercises"
}

# failing DIR: names `langlings verify` reports as failing in that workspace.
failing() {
	(cd "$1" && "$runner" verify odinlings) | sed 's/\x1b\[[0-9;]*m//g' | sed -n 's/^✗ //p'
}

status=0

setup "$tmp/solutions" "$here/solutions"
bad=$(failing "$tmp/solutions")
for name in $bad; do
	# `verify` checks everything in parallel, which has been seen to fail a
	# solution once in a long while. Check again on its own before blaming it.
	if out=$(cd "$tmp/solutions" && "$runner" run odinlings "$name" 2>&1); then
		echo "flaky: $name failed under parallel load, passed on its own"
	else
		echo "solution fails: $name"
		echo "$out" | sed 's/^/  /'
		status=1
	fi
done

setup "$tmp/exercises" "$here/exercises"
failed=$(failing "$tmp/exercises")
# name/file pairs from the track, one "name file" per line
awk -F' = ' '/^name = /{gsub(/"/,"",$2); n=$2} /^file = /{gsub(/"/,"",$2); print n, $2}' "$track" |
while read -r name file; do
	if ! echo "$failed" | grep -qx "$name"; then
		sol="$here/solutions/${file#exercises/}"
		if ! cmp -s "$here/$file" "$sol"; then
			echo "exercise passes as shipped: $name"
			exit 1
		fi
	fi
done || status=1

count=$(grep -c '^\[\[exercise\]\]' "$track")
if [ "$status" -eq 0 ]; then
	echo "ok: all $count solutions pass, and every exercise that should fail does"
fi
exit "$status"
