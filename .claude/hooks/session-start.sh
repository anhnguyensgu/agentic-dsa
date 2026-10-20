#!/bin/bash
# Claude Code on the web: builds Odin and `algo` so the algorithm-learning
# plugin's MCP server and `algo learn` work in the cloud container. Local
# sessions are left alone; follow algo/README.md there instead.
set -euo pipefail

if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
	exit 0
fi

ODIN_TAG=dev-2026-07
ODIN_DIR="$HOME/.local/share/odin"
BIN_DIR="$HOME/.local/bin"
PROJECT_DIR=${CLAUDE_PROJECT_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}

# Odin publishes no Linux build the container can download, so build it from
# source against the system LLVM. Skipped once the cached container has it.
if [ "$("$ODIN_DIR/odin" version 2>/dev/null | awk '{print $3}' | cut -d: -f1)" != "$ODIN_TAG" ]; then
	if ! llvm-config --libfiles >/dev/null 2>&1; then
		apt-get update -qq
		DEBIAN_FRONTEND=noninteractive apt-get install -y -qq llvm-dev >/dev/null
	fi
	rm -rf "$ODIN_DIR"
	mkdir -p "$(dirname "$ODIN_DIR")"
	GIT_LFS_SKIP_SMUDGE=1 git clone -q -c advice.detachedHead=false \
		--depth 1 --branch "$ODIN_TAG" https://github.com/odin-lang/Odin "$ODIN_DIR"
	(cd "$ODIN_DIR" && ./build_odin.sh release >/dev/null)
fi

# The plugin's launcher and `algo learn` find both on PATH; the MCP server may
# not see CLAUDE_ENV_FILE, so link into ~/.local/bin, which is already on PATH.
mkdir -p "$BIN_DIR"
ln -sf "$ODIN_DIR/odin" "$BIN_DIR/odin"
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
	echo "export PATH=\"$BIN_DIR:\$PATH\"" >>"$CLAUDE_ENV_FILE"
fi

# Rebuild every session so `algo` matches the checked-out branch.
PATH="$BIN_DIR:$PATH" make -s -C "$PROJECT_DIR/algo" install >/dev/null
