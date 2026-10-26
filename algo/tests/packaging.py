#!/usr/bin/env python3
"""Validate the one plugin that serves Claude Code, Codex, and Pi, without installing it."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
# plugins/, beside algo/, is the marketplace root for both Claude Code and Codex.
MARKETPLACE = ROOT.parent / "plugins"
PLUGIN = MARKETPLACE / "algorithm-learning"
LAUNCHER = PLUGIN / "scripts" / "launch_algolearn_mcp"
NAME = "algorithm-learning"
VERSION = "0.4.0"
MCP_HANDSHAKE = (
    '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-11-25"}}\n'
    '{"jsonrpc":"2.0","id":2,"method":"shutdown","params":{}}\n'
    '{"jsonrpc":"2.0","method":"exit","params":{}}\n'
)


def read_json(path: Path) -> dict:
    return json.loads(path.read_text())


def check_skill() -> None:
    # One skill, shared by every agent: no copies anywhere in the tree.
    skills = sorted(path.relative_to(ROOT.parent) for path in ROOT.parent.rglob("SKILL.md") if ".git" not in path.parts)
    assert skills == [Path("plugins/algorithm-learning/skills/algorithm-learning/SKILL.md")], skills
    for file in PLUGIN.rglob("*"):
        if file.is_file() and file.suffix in {".json", ".md", ".yaml"}:
            assert "[TODO:" not in file.read_text(errors="ignore")


def check_claude() -> None:
    manifest = read_json(PLUGIN / ".claude-plugin" / "plugin.json")
    assert manifest["name"] == NAME and manifest["version"] == VERSION
    # Inline, so Claude does not read the Codex-format .mcp.json.
    server = manifest["mcpServers"][NAME]
    assert server["command"] == "${CLAUDE_PLUGIN_ROOT}/scripts/launch_algolearn_mcp"

    [entry] = read_json(MARKETPLACE / ".claude-plugin" / "marketplace.json")["plugins"]
    assert entry["name"] == NAME and (MARKETPLACE / entry["source"]).resolve() == PLUGIN.resolve()

    # Claude's own validator, when this machine has Claude Code installed.
    if claude := shutil.which("claude"):
        for target in (PLUGIN, MARKETPLACE):
            result = subprocess.run([claude, "plugin", "validate", "--strict", str(target)], text=True, capture_output=True, timeout=60)
            assert result.returncode == 0, (target, result.stdout, result.stderr)


def check_codex() -> None:
    manifest = read_json(PLUGIN / ".codex-plugin" / "plugin.json")
    assert manifest["name"] == NAME and manifest["version"] == VERSION
    assert manifest["skills"] == "./skills/" and manifest["mcpServers"] == "./.mcp.json"
    server = read_json(PLUGIN / ".mcp.json")["mcpServers"][NAME]
    assert server["command"] == "./scripts/launch_algolearn_mcp"

    [entry] = read_json(MARKETPLACE / ".agents" / "plugins" / "marketplace.json")["plugins"]
    assert entry["name"] == NAME and entry["source"]["source"] == "local"
    assert (MARKETPLACE / entry["source"]["path"]).resolve() == PLUGIN.resolve()


def check_pi() -> None:
    package = read_json(PLUGIN / "package.json")
    assert package["name"] == NAME and package["version"] == VERSION
    assert package["private"] is True and "pi-package" in package["keywords"]
    assert package["pi"] == {"skills": ["./skills"]}


def check_no_binary() -> None:
    # The plugin ships no binary: algo comes from `make install` or ALGOLEARN_BIN.
    assert not (PLUGIN / "bin").exists()
    # The manifests' version follows the engine's.
    version = subprocess.run([str(ROOT / "bin" / "algo"), "learn", "version"], text=True, capture_output=True, check=True)
    assert f"algolearn {VERSION}" in version.stdout


def serve(launcher: Path, env: dict[str, str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run([str(launcher)], input=MCP_HANDSHAKE, text=True, capture_output=True, env=env, timeout=10)


def check_handshake(process: subprocess.CompletedProcess[str]) -> None:
    assert process.returncode == 0, process.stderr
    messages = [json.loads(line) for line in process.stdout.splitlines()]
    assert messages[0]["result"]["serverInfo"]["name"] == "algolearn"
    assert messages[1]["result"] is None


def check_launcher() -> None:
    assert os.access(LAUNCHER, os.X_OK)
    algo = ROOT / "bin" / "algo"
    with tempfile.TemporaryDirectory(prefix="algolearn-plugin-") as tmp:
        temp = Path(tmp)
        workspace = temp / "practice"
        workspace.mkdir()
        home = temp / "home"
        home.mkdir()
        # An isolated HOME, so a real ~/.local/bin/algo cannot satisfy a check.
        base = dict(os.environ, ALGOLEARN_WORKSPACE=str(workspace), HOME=str(home), PATH="/usr/bin:/bin")
        base.pop("ALGOLEARN_BIN", None)

        missing = serve(LAUNCHER, base)
        assert missing.returncode == 127 and "make install" in missing.stderr

        check_handshake(serve(LAUNCHER, dict(base, ALGOLEARN_BIN=str(algo))))

        path_dir = temp / "path"
        path_dir.mkdir()
        (path_dir / "algo").symlink_to(algo)
        check_handshake(serve(LAUNCHER, dict(base, PATH=f"{path_dir}:/usr/bin:/bin")))

        # Agent apps started outside a shell may lack ~/.local/bin on PATH.
        (home / ".local" / "bin").mkdir(parents=True)
        (home / ".local" / "bin" / "algo").symlink_to(algo)
        check_handshake(serve(LAUNCHER, base))


def check_install() -> None:
    with tempfile.TemporaryDirectory(prefix="algolearn-install-") as tmp:
        temp = Path(tmp)
        prefix = temp / "prefix"
        workspace = temp / "practice"
        workspace.mkdir()
        bin_dir = prefix / "bin"
        bin_dir.mkdir(parents=True)
        # Alias symlinks an older install left behind are removed; an unrelated
        # file with one of those names is kept.
        for name in ("leetcode", "kattis"):
            (bin_dir / name).symlink_to("algo")
        (bin_dir / "algolearn").write_text("unrelated\n")
        subprocess.run(["make", "install", f"PREFIX={prefix}"], cwd=ROOT, check=True, capture_output=True, text=True)
        algo = bin_dir / "algo"
        assert algo.is_file()
        assert not (bin_dir / "leetcode").is_symlink() and not (bin_dir / "kattis").is_symlink()
        assert (bin_dir / "algolearn").read_text() == "unrelated\n"
        initialized = subprocess.run([
            str(algo), "learn", "call", "workspace_init", "--workspace", str(workspace), "--input", "-", "--json",
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
        assert not algo.exists() and (bin_dir / "algolearn").exists() and events.read_bytes() == before


def main() -> None:
    check_skill()
    check_claude()
    check_codex()
    check_pi()
    check_no_binary()
    check_launcher()
    check_install()
    print("PASS: one plugin for Claude Code, Codex, and Pi: single skill, no bundled binary, manifests, launcher, and install")


if __name__ == "__main__":
    main()
