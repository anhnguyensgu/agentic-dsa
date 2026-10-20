#!/usr/bin/env python3
"""Validate the assembled Claude Code, Codex, and Pi plugins without installing them."""

import filecmp
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
REPO = ROOT.parent
SHARED_SKILL = ROOT / "skills" / "algorithm-learning"
LAUNCHER = ROOT / "scripts" / "launch_algolearn_mcp"
VERSION = "0.3.0"
MCP_HANDSHAKE = (
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}}\n'
    '{"jsonrpc":"2.0","id":2,"method":"shutdown","params":{}}\n'
    '{"jsonrpc":"2.0","method":"exit","params":{}}\n'
)


def plugin(host: str) -> Path:
    return ROOT / "plugins" / host / "algorithm-learning"


def same_tree(left: Path, right: Path) -> bool:
    comparison = filecmp.dircmp(left, right)
    if comparison.left_only or comparison.right_only or comparison.diff_files or comparison.funny_files:
        return False
    return all(same_tree(left / name, right / name) for name in comparison.common_dirs)


def check_shared_parts(host: str, launcher: bool) -> None:
    root = plugin(host)
    assert same_tree(SHARED_SKILL, root / "skills" / "algorithm-learning"), f"{host} skill copy is stale"
    script = root / "scripts" / LAUNCHER.name
    if launcher:
        assert filecmp.cmp(LAUNCHER, script, shallow=False) and os.access(script, os.X_OK), host
    else:
        assert not script.exists(), host
    for file in root.rglob("*"):
        if file.is_file() and file.suffix in {".json", ".md", ".yaml"}:
            assert "[TODO:" not in file.read_text(errors="ignore")


def serve(launcher: Path, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run([str(launcher)], input=MCP_HANDSHAKE, text=True, capture_output=True, env=env, timeout=10)


def check_handshake(process: subprocess.CompletedProcess[str]) -> None:
    assert process.returncode == 0, process.stderr
    messages = [json.loads(line) for line in process.stdout.splitlines()]
    assert messages[0]["result"]["serverInfo"]["name"] == "algolearn"
    assert messages[1]["result"] is None


def check_claude() -> None:
    root = plugin("claude")
    manifest = json.loads((root / ".claude-plugin" / "plugin.json").read_text())
    assert manifest["name"] == root.name and manifest["version"] == VERSION
    assert manifest["mcpServers"] == "./.mcp.json"
    mcp = json.loads((root / ".mcp.json").read_text())["mcpServers"]["algorithm-learning"]
    assert mcp["command"] == "${CLAUDE_PLUGIN_ROOT}/scripts/launch_algolearn_mcp"
    assert not (root / "bin").exists(), "the Claude plugin finds algo on PATH"
    check_shared_parts("claude", launcher=True)

    marketplace = json.loads((REPO / ".claude-plugin" / "marketplace.json").read_text())
    [entry] = marketplace["plugins"]
    assert entry["name"] == manifest["name"]
    assert (REPO / entry["source"]).resolve() == root.resolve()

    # Claude's own validator, when this machine has Claude Code installed.
    if claude := shutil.which("claude"):
        for target in (root, REPO):
            result = subprocess.run([claude, "plugin", "validate", "--strict", str(target)], text=True, capture_output=True, timeout=60)
            assert result.returncode == 0, (target, result.stdout, result.stderr)


def check_codex() -> None:
    root = plugin("codex")
    manifest = json.loads((root / ".codex-plugin" / "plugin.json").read_text())
    assert manifest["name"] == root.name and manifest["version"] == VERSION
    assert manifest["mcpServers"] == "./.mcp.json"
    mcp = json.loads((root / ".mcp.json").read_text())["mcpServers"]["algorithm-learning"]
    assert mcp["command"] == "./scripts/launch_algolearn_mcp"
    binary = root / "bin" / "algo"
    assert binary.is_file() and not binary.is_symlink()
    version = subprocess.run([str(binary), "learn", "version"], text=True, capture_output=True, check=True)
    assert f"algolearn {VERSION}" in version.stdout
    check_shared_parts("codex", launcher=True)

    marketplace = json.loads((REPO / ".agents" / "plugins" / "marketplace.json").read_text())
    [entry] = marketplace["plugins"]
    assert entry["name"] == manifest["name"] and entry["source"]["source"] == "local"
    assert (REPO / entry["source"]["path"]).resolve() == root.resolve()


def check_pi() -> None:
    root = plugin("pi")
    package = json.loads((root / "package.json").read_text())
    assert package["name"] == root.name and package["version"] == VERSION
    assert package["private"] is True and "pi-package" in package["keywords"]
    assert package["pi"] == {"skills": ["./skills"]}
    assert (root / "skills" / "algorithm-learning" / "SKILL.md").is_file()
    check_shared_parts("pi", launcher=False)


def check_launcher() -> None:
    with tempfile.TemporaryDirectory(prefix="algolearn-plugin-") as tmp:
        workspace = Path(tmp) / "practice"
        workspace.mkdir()
        base = dict(os.environ, ALGOLEARN_WORKSPACE=str(workspace))
        base.pop("ALGOLEARN_BIN", None)

        # Codex runs its bundled binary.
        check_handshake(serve(plugin("codex") / "scripts" / LAUNCHER.name, base))

        # Claude has no bundled binary and finds algo on PATH.
        path_dir = Path(tmp) / "path"
        path_dir.mkdir()
        (path_dir / "algo").symlink_to(ROOT / "bin" / "algo")
        claude = plugin("claude") / "scripts" / LAUNCHER.name
        check_handshake(serve(claude, dict(base, PATH=f"{path_dir}:/usr/bin:/bin")))
        check_handshake(serve(claude, dict(base, PATH="/usr/bin:/bin", ALGOLEARN_BIN=str(ROOT / "bin" / "algo"))))
        missing = serve(claude, dict(base, PATH="/usr/bin:/bin"))
        assert missing.returncode == 127 and "make install" in missing.stderr


def check_install() -> None:
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


def main() -> None:
    check_claude()
    check_codex()
    check_pi()
    check_launcher()
    check_install()
    print("PASS: Claude Code, Codex, and Pi plugins, shared skill copies, launcher, and install")


if __name__ == "__main__":
    main()
