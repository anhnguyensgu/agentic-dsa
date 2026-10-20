#!/usr/bin/env python3
"""Assemble each host's plugin from the shared skill, launcher, and binary.

plugins/<host>/algorithm-learning/ holds the host's own manifest files; this
script regenerates the parts shared by every host. Only the Codex plugin
bundles the native binary; the others find `algo` on PATH.
"""

from pathlib import Path
import shutil
import stat

ROOT = Path(__file__).resolve().parents[1]
SHARED_SKILL = ROOT / "skills" / "algorithm-learning"
LAUNCHER = ROOT / "scripts" / "launch_algolearn_mcp"
BINARY = ROOT / "bin" / "algo"

# host: (copies the MCP launcher, bundles the binary)
HOSTS = {
    "claude": (True, False),
    "codex": (True, True),
    "pi": (False, False),
}


def plugin_dir(host: str) -> Path:
    return ROOT / "plugins" / host / "algorithm-learning"


def make_executable(path: Path) -> None:
    path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def main() -> None:
    if not BINARY.is_file():
        raise SystemExit("build bin/algo before packaging")
    for host, (launcher, binary) in HOSTS.items():
        plugin = plugin_dir(host)
        skill = plugin / "skills" / "algorithm-learning"
        if skill.exists():
            shutil.rmtree(skill)
        shutil.copytree(SHARED_SKILL, skill)
        if launcher:
            (plugin / "scripts").mkdir(exist_ok=True)
            shutil.copy2(LAUNCHER, plugin / "scripts" / LAUNCHER.name)
            make_executable(plugin / "scripts" / LAUNCHER.name)
        if binary:
            (plugin / "bin").mkdir(exist_ok=True)
            # Copy the real file, not the build's symlink names.
            shutil.copy2(BINARY.resolve(), plugin / "bin" / "algo")
        print(f"Packaged {plugin}")


if __name__ == "__main__":
    main()
