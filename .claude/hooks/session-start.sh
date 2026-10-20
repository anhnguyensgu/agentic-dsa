#!/bin/bash
# Builds `algo` for the algorithm-learning plugin in Claude Code cloud sessions.
# Odin itself comes from the cloud environment's setup script. Skips the build
# when ~/.local/bin/algo is newer than every source file it is built from.
set -euo pipefail

[ "${CLAUDE_CODE_REMOTE:-}" = "true" ] || exit 0

algo_dir="$CLAUDE_PROJECT_DIR/algo"
binary="$HOME/.local/bin/algo"

if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
	echo "export PATH=\"$HOME/.local/bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

if ! command -v odin >/dev/null 2>&1; then
	echo "algorithm-learning: odin not found; add Odin to the cloud environment's setup script" >&2
	exit 0
fi

if [ -x "$binary" ] && [ -z "$(find "$algo_dir" \( -path "$algo_dir/bin" -o -path "$algo_dir/plugins" -o -path "$algo_dir/tests" \) -prune -o -type f -newer "$binary" -print -quit)" ]; then
	exit 0
fi

make -C "$algo_dir" install >&2
