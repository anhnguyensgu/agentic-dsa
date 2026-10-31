#!/usr/bin/env python3
"""End-to-end stateless practice tools without remote submissions."""

from __future__ import annotations

import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ALGO = ROOT / "bin" / "algo"
ENVELOPE = {"schema_version", "request_id", "status", "data", "events", "warnings", "error", "next_actions"}
SCHEMA = json.loads((ROOT / "schemas" / "event-v2.json").read_text())
EVENT = set(SCHEMA["required"])

SOLUTION = '''package main
import "core:fmt"
import "core:os"
import "core:strconv"
import "core:strings"
main :: proc() {
    data, _ := os.read_entire_file(os.stdin, context.allocator)
    n, _ := strconv.parse_int(strings.trim_space(string(data)))
    fmt.println("Bob" if n % 2 == 0 else "Alice")
}
'''


def case(case_input: str, expected: str | None, verified: bool = True) -> dict:
    return {
        "name": f"n={case_input.strip()}", "input": case_input, "expected": expected,
        "comparator": "exact", "provenance": "official_example", "oracle_verified": verified,
    }


def main() -> None:
    checks = 0
    with tempfile.TemporaryDirectory(prefix="algolearn-e2e-") as tmp:
        workspace = Path(tmp) / "practice"
        workspace.mkdir()

        def call(operation: str, payload: dict, expected: int = 0) -> dict:
            nonlocal checks
            result = subprocess.run(
                [str(ALGO), "learn", "call", operation, "--workspace", str(workspace), "--input", "-", "--json"],
                input=json.dumps(payload), text=True, capture_output=True, timeout=60,
            )
            checks += 1
            assert result.returncode == expected, (operation, result.returncode, result.stdout, result.stderr)
            envelope = json.loads(result.stdout)
            assert set(envelope) == ENVELOPE, envelope.keys()
            assert envelope["schema_version"] == 2
            for event in envelope["events"]:
                assert set(event) == EVENT and event["schema_version"] == 2
                assert event["event_id"].startswith("ev_") and event["timestamp"].endswith("Z")
                # Only the tool-emitted kinds come from the tools, with every documented payload field.
                assert event["type"] in SCHEMA["x-tool-emitted"], event["type"]
                payload_schema = SCHEMA["$defs"][event["type"]]
                assert set(payload_schema["required"]) <= set(event["payload"]), (event["type"], event["payload"].keys())
            return envelope

        doctor = call("doctor", {})
        assert doctor["data"]["ready_for_local_practice"] is True
        assert {provider["provider"] for provider in doctor["data"]["providers"]} == {"leetcode", "kattis", "exercism"}
        assert doctor["events"] == []
        # Learning paths belong to the agent; the tools carry no curriculum.
        gone = call("curriculum_get", {}, expected=1)
        assert gone["error"]["code"] == "not_found"

        attempt = call("attempt_start", {
            "problem_key": "kattis:twostones", "language": "odin", "session_id": "my-session",
        })
        data = attempt["data"]
        assert data["attempt_id"].startswith("att_") and data["fresh"] is True
        assert data["source_path"].startswith("problems/kattis/twostones/att_")
        [started] = attempt["events"]
        assert started["type"] == "attempt_started" and started["session_id"] == "my-session"
        assert started["attempt_id"] == data["attempt_id"]
        assert started["payload"]["source_hash"] == data["source_hash"]
        second = call("attempt_start", {"problem_key": "kattis:twostones", "language": "odin"})
        assert second["data"]["attempt_id"] != data["attempt_id"]

        source = workspace / data["source_path"]
        source.write_text(SOLUTION)
        ids = {"session_id": "my-session", "attempt_id": data["attempt_id"]}

        passed = call("test_run", dict(ids, source_path=data["source_path"], timeout_seconds=5,
                                        cases=[case("1\n", "Alice\n"), case("2\n", "Bob\n")]))
        assert passed["data"]["outcome"] == "passed" and passed["data"]["verified_passed"] == 2
        [observed] = passed["events"]
        assert observed["type"] == "runner_observed" and observed["attempt_id"] == data["attempt_id"]
        # The event is self-contained: every case result rides along.
        assert [c["case_id"] for c in observed["payload"]["cases"]] == ["case_1", "case_2"]
        assert observed["payload"]["cases"][0]["actual"] == "Alice\n"

        wrong = call("test_run", dict(ids, source_path=data["source_path"], cases=[case("1\n", "Bob\n")]), expected=3)
        assert wrong["data"]["outcome"] == "failed" and wrong["data"]["verified_failed"] == 1
        unchecked = call("test_run", {"source_path": data["source_path"], "cases": [case("3\n", None)]}, expected=4)
        assert unchecked["data"]["outcome"] == "unverified" and unchecked["data"]["unchecked"] == 1
        # A claimed oracle without an expected output is never verified.
        claimed = call("test_run", {"source_path": data["source_path"], "cases": [case("3\n", None, verified=True)]}, expected=4)
        assert claimed["data"]["cases"][0]["verified"] is False
        empty = call("test_run", {"source_path": data["source_path"]}, expected=4)
        assert any("zero cases" in warning for warning in empty["warnings"])

        source.write_text("package main\nmain :: proc() { nope }\n")
        broken = call("test_run", {"source_path": data["source_path"], "cases": [case("1\n", "Alice\n")]}, expected=3)
        assert broken["data"]["outcome"] == "compile_error" and broken["data"]["cases"][0]["stderr"]
        source.write_text(SOLUTION)

        # Invalid inputs fail fast, before anything runs.
        for operation, payload in (
            ("attempt_start", {"problem_key": "kattis:twostones", "language": "odin", "expected_revision": 3}),
            ("attempt_start", {"problem_key": "codeforces:1a", "language": "odin"}),
            ("attempt_start", {"problem_key": "leetcode:../x", "language": "odin"}),
            ("test_run", {"source_path": "../outside.odin"}),
            ("test_run", {"source_path": data["source_path"], "cases": [dict(case("1\n", "Alice\n"), comparator="fuzzy")]}),
            ("test_run", {"source_path": data["source_path"], "cases": [dict(case("1\n", "Alice\n"), provenance="")]}),
            ("job_check", {"provider": "codeforces", "remote_id": "1"}),
            ("job_check", {"provider": "kattis", "remote_id": "--json"}),
        ):
            rejected = call(operation, payload, expected=2)
            assert rejected["error"]["code"] == "invalid_input" and rejected["events"] == [], (operation, payload)

        # LeetCode does not judge Odin; nothing is sent.
        lc = call("attempt_start", {"problem_key": "leetcode:trapping-rain-water", "language": "odin"})
        refused = call("submit", {
            "problem_key": "leetcode:trapping-rain-water", "language": "odin",
            "source_path": lc["data"]["source_path"], "authorization_reference": "learner asked",
        }, expected=1)
        assert refused["error"]["code"] == "unsupported_capability" and refused["events"] == []
        # A source that changed since it was tested is refused.
        stale = call("submit", {
            "problem_key": "kattis:twostones", "language": "odin", "source_path": data["source_path"],
            "source_hash": "0" * 64, "authorization_reference": "learner asked",
        }, expected=1)
        assert stale["error"]["code"] == "stale_source" and stale["events"] == []

        # The tools store nothing.
        assert not (workspace / ".algo").exists()

        # Without --workspace the tools use the global algo workspace.
        defaulted = subprocess.run(
            [str(ALGO), "learn", "doctor", "--json"],
            env=dict(os.environ, ALGO_WORKSPACE=str(workspace)), text=True, capture_output=True, timeout=30,
        )
        checks += 1
        assert defaulted.returncode == 0, (defaulted.stdout, defaulted.stderr)
        assert json.loads(defaulted.stdout)["data"]["workspace_accessible"] is True

        print(f"PASS: {checks} stateless practice end-to-end checks (no remote submissions)")


if __name__ == "__main__":
    main()
