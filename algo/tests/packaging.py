#!/usr/bin/env python3
"""Validate the assembled native plugin without installing it."""

import filecmp
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "plugins" / "codex" / "algorithm-learning"


def main() -> None:
    manifest = json.loads((PLUGIN / ".codex-plugin" / "plugin.json").read_text())
    assert manifest["name"] == PLUGIN.name == "algorithm-learning"
    assert manifest["mcpServers"] == "./.mcp.json"
    mcp = json.loads((PLUGIN / ".mcp.json").read_text())["mcpServers"]["algorithm-learning"]
    assert mcp["command"] == "./scripts/launch_algolearn_mcp"
    assert (PLUGIN / "bin" / "algo").is_file() and not (PLUGIN / "bin" / "algo").is_symlink()
    assert not (PLUGIN / "bin" / "algolearn").exists()
    comparison = filecmp.dircmp(ROOT / "skills" / "algorithm-learning", PLUGIN / "skills" / "algorithm-learning")
    assert not comparison.left_only and not comparison.right_only and not comparison.diff_files
    for file in PLUGIN.rglob("*"):
        if file.is_file() and file.suffix in {".json", ".md", ".yaml"}:
            assert "[TODO:" not in file.read_text(errors="ignore")
    version = subprocess.run([str(PLUGIN / "bin" / "algo"), "learn", "version"], text=True, capture_output=True, check=True)
    assert "algolearn 0.2.0" in version.stdout
    with tempfile.TemporaryDirectory(prefix="algolearn-plugin-") as workspace:
        env = dict(os.environ, ALGOLEARN_WORKSPACE=workspace)
        process = subprocess.run(
            [str(PLUGIN / "scripts" / "launch_algolearn_mcp")],
            input='{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}}\n'
                  '{"jsonrpc":"2.0","id":2,"method":"shutdown","params":{}}\n'
                  '{"jsonrpc":"2.0","method":"exit","params":{}}\n',
            text=True, capture_output=True, env=env, timeout=10, check=True,
        )
        messages = [json.loads(line) for line in process.stdout.splitlines()]
        assert messages[0]["result"]["serverInfo"]["name"] == "algolearn"
        assert messages[1]["result"] is None
    with tempfile.TemporaryDirectory(prefix="algolearn-install-") as tmp:
        temp = Path(tmp)
        prefix = temp / "prefix"
        workspace = temp / "practice"
        workspace.mkdir()
        subprocess.run(["make", "install", f"PREFIX={prefix}"], cwd=ROOT, check=True, capture_output=True, text=True)
        installed = prefix / "bin" / "algolearn"
        assert (prefix / "bin" / "algo").is_file()
        for name in ("leetcode", "kattis", "algolearn"):
            assert os.readlink(prefix / "bin" / name) == "algo"
        initialized = subprocess.run([
            str(installed), "call", "workspace_init", "--workspace", str(workspace), "--input", "-", "--json",
        ], input=json.dumps({
            "request_id": "install-init", "expected_revision": 0,
            "goal": "foundations", "language": "odin", "timezone": "UTC",
            "experience": "beginner", "time_budget_minutes": 20,
        }), text=True, capture_output=True, check=True)
        assert json.loads(initialized.stdout)["workspace_revision"] == 1
        events = workspace / ".algo" / "learning" / "events.jsonl"
        before = events.read_bytes()
        subprocess.run(["make", "install", f"PREFIX={prefix}"], cwd=ROOT, check=True, capture_output=True, text=True)
        assert events.read_bytes() == before
        subprocess.run(["make", "uninstall", f"PREFIX={prefix}"], cwd=ROOT, check=True, capture_output=True, text=True)
        assert not installed.exists() and not (prefix / "bin" / "algo").exists() and events.read_bytes() == before
    print("PASS: native plugin bundle, shared skill copy, launcher, and manifest")


if __name__ == "__main__":
    main()
