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
        attempt = cli(workspace, "attempt_start", {"problem_key": "kattis:twostones", "language": "odin"})
        source = workspace / attempt["data"]["source_path"]
        source.write_text('package main\nmain :: proc() { for {} }\n')

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
        assert names == {"doctor", "curriculum_get", "attempt_start", "test_run", "submit", "job_check"}
        assert all("inputSchema" in tool and "outputSchema" in tool and tool["description"] for tool in tools)
        by_name = {tool["name"]: tool for tool in tools}
        assert "events" in by_name["doctor"]["outputSchema"]["required"]
        assert set(by_name["submit"]["inputSchema"]["required"]) == {"problem_key", "language", "source_path", "authorization_reference"}
        cases = by_name["test_run"]["inputSchema"]["properties"]["cases"]
        assert cases["type"] == "array" and set(cases["items"]["required"]) == {"input", "comparator", "provenance"}
        checks += 1

        send({"jsonrpc": "2.0", "id": 3, "method": "tools/call", "params": {"name": "curriculum_get", "arguments": {}}})
        mcp_curriculum = receive(3)["result"]
        assert mcp_curriculum["isError"] is False
        assert json.loads(mcp_curriculum["content"][0]["text"]) == mcp_curriculum["structuredContent"]
        cli_curriculum = cli(workspace, "curriculum_get", {})
        assert mcp_curriculum["structuredContent"]["data"] == cli_curriculum["data"]
        checks += 1

        send({"jsonrpc": "2.0", "id": 4, "method": "tools/call", "params": {"name": "attempt_start", "arguments": {
            "problem_key": "kattis:twostones", "language": "odin", "session_id": "mcp-session"}}})
        started = receive(4)["result"]["structuredContent"]
        assert started["events"][0]["type"] == "attempt_started" and started["events"][0]["actor"] == "agent:mcp"
        checks += 1

        process.stdin.write("not-json\n")
        process.stdin.flush()
        malformed = receive(None)
        assert malformed["error"]["code"] == -32700
        checks += 1

        send({
            "jsonrpc": "2.0", "id": 50, "method": "tools/call",
            "params": {"name": "test_run", "arguments": {
                "request_id": "mcp-run", "source_path": attempt["data"]["source_path"], "timeout_seconds": 3,
                "cases": [{"input": "", "expected": "done\n", "comparator": "exact", "provenance": "fixture", "oracle_verified": True}],
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
        assert not (workspace / ".algo").exists()
        checks += 1
        print(f"PASS: {checks} native MCP protocol checks")


if __name__ == "__main__":
    main()
