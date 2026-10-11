#!/usr/bin/env python3
"""Assemble the Codex wrapper from the shared skill and current native binary."""

from pathlib import Path
import shutil
import stat

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "plugins" / "codex" / "algorithm-learning"
SHARED_SKILL = ROOT / "skills" / "algorithm-learning"
PLUGIN_SKILL = PLUGIN / "skills" / "algorithm-learning"
BINARY = ROOT / "bin" / "algo"


def main() -> None:
    if not BINARY.is_file():
        raise SystemExit("build bin/algo before packaging")
    if PLUGIN_SKILL.exists():
        shutil.rmtree(PLUGIN_SKILL)
    shutil.copytree(SHARED_SKILL, PLUGIN_SKILL)
    target_bin = PLUGIN / "bin"
    target_bin.mkdir(parents=True, exist_ok=True)
    stale = target_bin / "algolearn"
    if stale.exists() or stale.is_symlink():
        stale.unlink()
    # The launcher runs `algo learn serve`; copy the real file, not a symlink.
    shutil.copy2(BINARY.resolve(), target_bin / "algo")
    launcher = PLUGIN / "scripts" / "launch_algolearn_mcp"
    launcher.chmod(launcher.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)
    print(f"Packaged {PLUGIN}")


if __name__ == "__main__":
    main()
