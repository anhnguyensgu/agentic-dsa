#!/usr/bin/env python3
"""Exercism pass-through checks against a stub exercism CLI; nothing reaches exercism.org."""

import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ALGO = ROOT / "bin" / "algo"

# The stub records its working directory and arguments, saves the workspace
# that `configure --workspace` sets the way the real CLI does, prints to both
# streams, and exits with EXERCISM_STUB_EXIT.
STUB = r'''#!/bin/sh
{ pwd; for arg in "$@"; do printf '%s\n' "$arg"; done; } > "$EXERCISM_STUB_LOG"
if [ "$1" = configure ] && [ "$2" = --workspace ]; then
	printf '{"apibaseurl":"http://127.0.0.1:9","token":"synthetic","workspace":"%s"}' "$3" > "$EXERCISM_CONFIG_HOME/user.json"
fi
echo "stub stdout"
echo "stub stderr" >&2
exit "${EXERCISM_STUB_EXIT:-0}"
'''


def main() -> None:
    checks = 0
    with tempfile.TemporaryDirectory(prefix="exercism-integration-") as tmp:
        tmp_path = Path(tmp)
        stub_dir = tmp_path / "stub-bin"
        stub_dir.mkdir()
        (stub_dir / "exercism").write_text(STUB)
        (stub_dir / "exercism").chmod(0o755)
        config_home = tmp_path / "exercism-config"
        config_home.mkdir()
        config = config_home / "user.json"
        root = tmp_path / "algo-root"
        exercises = root / "problems" / "exercism"
        log = tmp_path / "stub.log"
        work = tmp_path / "cwd"
        work.mkdir()
        base = dict(os.environ, PATH=f"{stub_dir}:/usr/bin:/bin", ALGO_WORKSPACE=str(root),
                    EXERCISM_CONFIG_HOME=str(config_home), EXERCISM_STUB_LOG=str(log))
        base.pop("EXERCISM_STUB_EXIT", None)
        base.pop("XDG_CONFIG_HOME", None)

        def run(argv, expected, env):
            nonlocal checks
            result = subprocess.run(argv, cwd=work, text=True, capture_output=True, timeout=30, env=env)
            checks += 1
            assert result.returncode == expected, (argv, result.returncode, result.stdout, result.stderr)
            return result

        def cli(*args, expected=0, extra_env=None):
            return run([str(ALGO), "judge", "exercism", *args], expected, dict(base, **(extra_env or {})))

        def stub_call():
            """The stub's working directory and arguments; None when it did not run."""
            if not log.exists():
                return None
            cwd, *args = log.read_text().splitlines()
            log.unlink()
            return Path(cwd).resolve(), args

        listed = run([str(ALGO), "judge"], 0, base)
        assert any(line.split() == ["exercism", "exercism-odin", "0.1.0"] for line in listed.stdout.splitlines())
        assert "setup" in cli(expected=2).stdout
        capabilities = json.loads(cli("capabilities").stdout)
        assert capabilities["provider"] == "exercism" and capabilities["structured"] is False
        assert json.loads(cli("capabilities", "--json").stdout) == capabilities
        cli("capabilities", "--wat", expected=2)
        cli("setup", "extra", expected=2)
        assert stub_call() is None

        # Commands that do not touch exercises pass through before setup, with
        # their output unchanged and in the caller's directory.
        version = cli("version")
        assert version.stdout == "stub stdout\n" and version.stderr == "stub stderr\n"
        assert stub_call() == (work.resolve(), ["version"])

        # Exercise commands refuse to run until setup; their help does not.
        refused = cli("download", "--track=odin", "--exercise=hello-world", expected=1)
        assert "exercism configure --token" in refused.stderr and stub_call() is None
        cli("download", "--help")
        assert stub_call() == (work.resolve(), ["download", "--help"])

        cli("setup")
        assert stub_call() == (work.resolve(), ["configure", "--workspace", str(exercises.resolve())])
        assert exercises.is_dir()

        download = ["download", "--track=odin", "--exercise=hello-world"]
        cli(*download)
        assert stub_call() == (work.resolve(), download)
        cli("--timeout", "5", "d", "--track=odin", "--exercise=two-fer")
        assert stub_call() == (work.resolve(), ["--timeout", "5", "d", "--track=odin", "--exercise=two-fer"])

        # A failing test is a failed solution (3); other failures are errors (1).
        cli("test")
        cli("test", expected=3, extra_env={"EXERCISM_STUB_EXIT": "1"})
        cli("t", expected=3, extra_env={"EXERCISM_STUB_EXIT": "255"})
        cli("submit", expected=1, extra_env={"EXERCISM_STUB_EXIT": "255"})
        assert stub_call() == (work.resolve(), ["submit"])

        # A workspace changed outside algo stops exercise commands only.
        config.write_text(json.dumps({"token": "synthetic", "workspace": str(tmp_path / "elsewhere")}))
        moved = cli("submit", expected=1)
        assert "algo judge exercism setup" in moved.stderr and stub_call() is None
        cli("troubleshoot")
        assert stub_call() == (work.resolve(), ["troubleshoot"])
        config.write_text("{not json")
        cli("open", expected=1)
        assert stub_call() is None

        # Without EXERCISM_CONFIG_HOME the CLI's config is under XDG_CONFIG_HOME.
        xdg = tmp_path / "xdg"
        (xdg / "exercism").mkdir(parents=True)
        (xdg / "exercism" / "user.json").write_text(json.dumps({"workspace": str(exercises)}))
        xdg_env = dict(base, XDG_CONFIG_HOME=str(xdg))
        xdg_env.pop("EXERCISM_CONFIG_HOME")
        run([str(ALGO), "judge", "exercism", *download], 0, xdg_env)
        assert stub_call() == (work.resolve(), download)

        missing = cli("version", expected=1, extra_env={"PATH": "/usr/bin:/bin"})
        assert "not on PATH" in missing.stderr
        print(f"PASS: {checks} Exercism pass-through checks")


if __name__ == "__main__":
    main()
