#!/usr/bin/env python3
"""End-to-end learning workflow without remote submissions."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / "bin" / "algolearn"


def main() -> None:
    checks = 0
    with tempfile.TemporaryDirectory(prefix="algolearn-e2e-") as tmp:
        workspace = Path(tmp) / "practice"
        workspace.mkdir()
        legacy = workspace / ".algo"
        legacy.mkdir()
        legacy_config = b'{"format_version":1,"track":"odin","test_command":"do not execute"}\n'
        legacy_events = b'{"ts":"2026-09-18T00:00:00Z","id":"001","event":"attempt"}\n'
        (legacy / "config.json").write_bytes(legacy_config)
        (legacy / "events.jsonl").write_bytes(legacy_events)
        original_hashes = {
            "config": hashlib.sha256(legacy_config).hexdigest(),
            "events": hashlib.sha256(legacy_events).hexdigest(),
        }

        def call(operation: str, payload: dict, expected: int = 0, ws: Path = workspace) -> dict:
            nonlocal checks
            result = subprocess.run(
                [str(BINARY), "call", operation, "--workspace", str(ws), "--input", "-", "--json"],
                input=json.dumps(payload), text=True, capture_output=True, timeout=30,
            )
            checks += 1
            assert result.returncode == expected, (operation, result.returncode, result.stdout, result.stderr)
            envelope = json.loads(result.stdout)
            assert set(envelope) == {"schema_version", "request_id", "workspace_revision", "status", "data", "warnings", "error", "next_actions"}
            return envelope

        initialized = call("workspace_init", {
            "request_id": "init-1", "expected_revision": 0,
            "goal": "foundations", "language": "odin", "timezone": "Asia/Ho_Chi_Minh",
            "experience": "beginner", "explanation_language": "English",
            "time_budget_minutes": 30,
        })
        assert initialized["workspace_revision"] == 1
        assert any("legacy" in warning for warning in initialized["warnings"])

        doctor = call("doctor", {})
        assert doctor["data"]["ready_for_local_practice"] is True
        assert doctor["data"]["catalog_problem_count"] >= 36
        assert {provider["provider"] for provider in doctor["data"]["providers"]} == {"leetcode", "kattis"}

        plan = call("plan_next", {"topic": "foundations", "time_budget_minutes": 30, "language": "odin"})
        assert plan["data"]["candidates"]
        assert isinstance(plan["data"]["candidates"][0], dict)

        session = call("session_start", {
            "request_id": "session-1", "expected_revision": 1,
            "objective": "explain parity and test both branches", "mode": "independent",
            "concept_ids": ["foundations"], "problem_key": "kattis:twostones",
        })
        session_id = session["data"]["session_id"]
        assert session_id == "sess_000002"

        attempt = call("attempt_start", {
            "request_id": "attempt-1", "expected_revision": 2,
            "session_id": session_id, "problem_key": "kattis:twostones",
            "language": "odin", "runner_kind": "stdin_stdout",
        })
        attempt_id = attempt["data"]["attempt_id"]
        source = workspace / attempt["data"]["source_path"]
        solution = '''package main
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
        source.write_text(solution)

        revision = 3
        for index, (case_input, expected) in enumerate((("1\n", "Alice\n"), ("2\n", "Bob\n"))):
            case = call("case_add", {
                "request_id": f"case-{index}", "expected_revision": revision,
                "attempt_id": attempt_id, "name": f"branch-{index}", "input": case_input,
                "expected": expected, "comparator": "exact", "provenance": "official_example",
                "oracle_verified": True, "oracle_basis": "Kattis sample/parity derivation",
            })
            assert case["data"]["verified_oracle"] is True
            revision += 1

        run = call("test_run", {
            "request_id": "run-1", "expected_revision": revision,
            "attempt_id": attempt_id, "mode": "local", "timeout_seconds": 5,
        })
        assert run["data"]["outcome"] == "passed"
        assert run["data"]["verified_passed"] == 2
        revision += 1
        evidence_id = json.loads((workspace / ".algo" / "learning" / "events.jsonl").read_text().splitlines()[-1])["event_id"]

        for dimension in ("approach", "correctness", "complexity"):
            assessment = call("assessment_record", {
                "request_id": f"assess-{dimension}", "expected_revision": revision,
                "session_id": session_id, "concept_id": "foundations", "dimension": dimension,
                "score": 3, "rationale": f"learner independently justified {dimension}",
                "rubric_version": "1", "evidence_ids": [evidence_id],
            })
            assert assessment["status"] == "completed"
            revision += 1

        checkpoint = call("session_checkpoint", {
            "request_id": "checkpoint-1", "expected_revision": revision,
            "session_id": session_id, "activity": "reflecting",
            "summary": "Used parity and verified odd/even branches.",
            "next_action": "Explain why only parity matters.",
        })
        assert (workspace / checkpoint["data"]["handoff_json"]).is_file()
        revision += 1

        closed = call("session_close", {
            "request_id": "close-1", "expected_revision": revision,
            "session_id": session_id, "reason": "completed",
        })
        assert closed["data"]["independent"] is True
        revision += 1

        state = call("state_get", {})
        assert isinstance(state["data"]["sessions"][0], dict)
        assert isinstance(state["data"]["attempts"][0], dict)
        progress = call("progress_get", {})
        assert progress["data"]["counts"]["independent_sessions"] == 1
        assert progress["data"]["execution"]["verified_passed_runs"] == 1
        assert progress["data"]["concepts"][0]["state"] == "independent"

        prepared = call("submission_prepare", {
            "request_id": "prepare-1", "expected_revision": revision,
            "attempt_id": attempt_id,
        })
        intent_id = prepared["data"]["intent_id"]
        revision += 1
        source.write_text(solution + "// changed after preparation\n")
        stale = call("submission_send", {
            "request_id": "send-stale", "expected_revision": revision,
            "intent_id": intent_id, "authorization_reference": "test-explicit-request",
        }, expected=1)
        assert stale["error"]["code"] == "stale_source"
        source.write_text(solution)

        unsupported_session = call("session_start", {
            "request_id": "session-lc", "expected_revision": revision,
            "objective": "local LeetCode practice", "mode": "guided", "concept_ids": ["maps-sets"],
        })
        revision += 1
        lc_attempt = call("attempt_start", {
            "request_id": "attempt-lc", "expected_revision": revision,
            "session_id": unsupported_session["data"]["session_id"], "problem_key": "leetcode:two-sum",
            "language": "odin", "runner_kind": "stdin_stdout",
        })
        revision += 1
        refused = call("submission_prepare", {
            "request_id": "prepare-lc", "expected_revision": revision,
            "attempt_id": lc_attempt["data"]["attempt_id"],
        }, expected=1)
        assert refused["error"]["code"] == "unsupported_capability"

        export = call("export_create", {
            "request_id": "export-1", "expected_revision": revision,
            "scope": "profile_history", "include_source": True,
        })
        export_path = workspace / export["data"]["path"]
        assert export_path.is_file()
        revision += 1

        legacy_preview = call("import_validate", {"kind": "legacy"})
        assert legacy_preview["data"]["unresolved_events"] == 1
        assert legacy_preview["data"]["test_command_will_execute"] is False
        assert hashlib.sha256((legacy / "config.json").read_bytes()).hexdigest() == original_hashes["config"]
        assert hashlib.sha256((legacy / "events.jsonl").read_bytes()).hexdigest() == original_hashes["events"]

        legacy_applied = call("import_apply", {
            "request_id": "legacy-apply", "expected_revision": revision,
            "kind": "legacy", "source_hash": legacy_preview["data"]["source_hash"],
        })
        assert legacy_applied["data"]["unresolved_events"] == 1
        revision += 1
        legacy_replayed = call("import_apply", {
            "request_id": "legacy-apply-again", "expected_revision": revision,
            "kind": "legacy", "source_hash": legacy_preview["data"]["source_hash"],
        })
        assert legacy_replayed["data"]["replayed"] is True

        delete_preview = call("data_delete", {"scope": "session", "session_id": session_id})
        assert delete_preview["data"]["preview"] is True
        assert delete_preview["data"]["will_preserve_solutions"] is True

        imported_workspace = Path(tmp) / "imported"
        imported_workspace.mkdir()
        transfer = imported_workspace / "transfer.json"
        shutil.copy2(export_path, transfer)
        preview = call("import_validate", {"kind": "export", "path": "transfer.json"}, ws=imported_workspace)
        applied = call("import_apply", {
            "request_id": "import-1", "expected_revision": 0, "kind": "export",
            "path": "transfer.json", "source_hash": preview["data"]["source_hash"],
        }, ws=imported_workspace)
        assert applied["data"]["imported_events"] > 0
        imported_state = call("state_get", {}, ws=imported_workspace)
        assert imported_state["data"]["profile"]["goal"] == "foundations"
        imported_source = imported_workspace / attempt["data"]["source_path"]
        assert imported_source.read_text() == solution

        print(f"PASS: {checks} Algorithm Learning end-to-end checks (no remote submissions)")


if __name__ == "__main__":
    main()
