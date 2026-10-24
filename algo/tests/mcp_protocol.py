#!/usr/bin/env python3
"""Exercise the native MCP process over its actual stdin/stdout."""

from __future__ import annotations

import json
from pathlib import Path
import selectors
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
ALGO = ROOT / "bin" / "algo"


def cli(workspace: Path, operation: str, payload: dict, expected: int = 0) -> dict:
    result = subprocess.run(
        [str(ALGO), "learn", "call", operation, "--workspace", str(workspace), "--input", "-", "--json"],
        input=json.dumps(payload), text=True, capture_output=True, timeout=30,
    )
    assert result.returncode == expected, (operation, result.returncode, result.stdout, result.stderr)
    return json.loads(result.stdout)


def main() -> None:
    checks = 0
    with tempfile.TemporaryDirectory(prefix="algolearn-mcp-") as tmp:
        workspace = Path(tmp)
        cli(workspace, "workspace_init", {
            "request_id": "init", "expected_revision": 0, "goal": "foundations",
            "language": "odin", "timezone": "UTC", "experience": "beginner",
            "time_budget_minutes": 20,
        })
        session = cli(workspace, "session_start", {
            "request_id": "session", "expected_revision": 1,
            "objective": "bounded execution", "mode": "guided", "concept_ids": ["foundations"],
        })
        attempt = cli(workspace, "attempt_start", {
            "request_id": "attempt", "expected_revision": 2,
            "session_id": session["data"]["session_id"], "problem_key": "kattis:twostones",
            "language": "odin", "runner_kind": "stdin_stdout",
        })
        source = workspace / attempt["data"]["source_path"]
        source.write_text('package main\nmain :: proc() { for {} }\n')
        cli(workspace, "case_add", {
            "request_id": "case", "expected_revision": 3,
            "attempt_id": attempt["data"]["attempt_id"], "input": "",
            "expected": "done\n", "comparator": "exact", "provenance": "fixture",
            "oracle_verified": True,
        })

        process = subprocess.Popen(
            [str(ALGO), "learn", "serve", "--workspace", str(workspace)],
            stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=subprocess.PIPE,
            text=True, bufsize=1,
        )
        assert process.stdin and process.stdout and process.stderr
        selector = selectors.DefaultSelector()
        selector.register(process.stdout, selectors.EVENT_READ)
        seen_lines: list[str] = []

        def send(message: dict) -> None:
            process.stdin.write(json.dumps(message, separators=(",", ":")) + "\n")
            process.stdin.flush()

        def receive(expected_id, timeout: float = 10.0) -> dict:
            deadline = time.monotonic() + timeout
            while time.monotonic() < deadline:
                ready = selector.select(deadline - time.monotonic())
                assert ready, ("timeout", expected_id, process.stderr.read() if process.poll() is not None else "")
                line = process.stdout.readline()
                assert line, ("server exited", process.returncode, process.stderr.read())
                seen_lines.append(line)
                message = json.loads(line)
                if message.get("id") == expected_id:
                    return message
            raise AssertionError(("timeout", expected_id))

        send({"jsonrpc": "2.0", "id": 0, "method": "initialize", "params": {"protocolVersion": "2025-01-01"}})
        assert receive(0)["error"]["code"] == -32602
        checks += 1
        send({"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-11-25"}})
        initialized = receive(1)["result"]
        assert initialized["protocolVersion"] == "2025-11-25"
        checks += 1
        send({"jsonrpc": "2.0", "method": "notifications/initialized", "params": {}})
        send({"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}})
        tools = receive(2)["result"]["tools"]
        names = {tool["name"] for tool in tools}
        required = {
            "workspace_init", "doctor", "profile_update", "state_get",
            "plan_next", "session_start", "session_resume", "attempt_start", "evidence_record", "hint_record",
            "case_add", "test_run", "submission_prepare", "submission_send", "job_check", "assessment_record",
            "session_checkpoint", "session_close", "review_due", "review_update", "progress_get", "export_create",
            "import_validate", "import_apply", "data_delete",
        }
        assert names == required
        assert all("inputSchema" in tool and "outputSchema" in tool for tool in tools)
        checks += 1

        send({"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "state_get", "arguments": {}}})
        mcp_state = receive(3)["result"]
        assert mcp_state["isError"] is False
        assert json.loads(mcp_state["content"][0]["text"]) == mcp_state["structuredContent"]
        cli_state = cli(workspace, "state_get", {})
        assert mcp_state["structuredContent"]["data"] == cli_state["data"]
        checks += 1

        process.stdin.write("not-json\n")
        process.stdin.flush()
        malformed = receive(None)
        assert malformed["error"]["code"] == -32700
        checks += 1

        send({
            "jsonrpc": "2.0", "id": 50, "method": "tools/call",
            "params": {"name": "test_run", "arguments": {
                "request_id": "mcp-run", "expected_revision": 4,
                "attempt_id": attempt["data"]["attempt_id"], "mode": "local", "timeout_seconds": 3,
            }},
        })
        send({"jsonrpc": "2.0", "method": "notifications/cancelled", "params": {"requestId": 50, "reason": "fixture cancellation"}})
        cancelled = receive(50)
        assert cancelled["error"]["code"] == -32800
        checks += 1

        send({"jsonrpc": "2.0", "id": 60, "method": "ping", "params": {}})
        assert receive(60)["result"] == {}
        checks += 1
        send({"jsonrpc": "2.0", "id": 61, "method": "shutdown", "params": {}})
        assert receive(61)["result"] is None
        send({"jsonrpc": "2.0", "method": "exit", "params": {}})
        process.stdin.close()
        assert process.wait(timeout=15) == 0
        assert all(json.loads(line)["jsonrpc"] == "2.0" for line in seen_lines)
        checks += 1
        print(f"PASS: {checks} native MCP protocol checks")


if __name__ == "__main__":
    main()
