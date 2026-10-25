#!/usr/bin/env python3
"""Exercism through the learning engine: plan_next suggestions, downloads,
test-package runs, and uploads, against a stub exercism CLI and a fixture
catalogue. Nothing reaches exercism.org or GitHub."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]

CATALOGUE = {"exercises": {"practice": [
    {"slug": "leap", "name": "Leap", "difficulty": 1, "practices": []},
    {"slug": "isogram", "name": "Isogram", "difficulty": 2},
    {"slug": "difference-of-squares", "name": "Difference of Squares", "difficulty": 2, "status": "active"},
    {"slug": "sieve", "name": "Sieve", "difficulty": 5, "status": "wip"},
]}}

# The stub downloads leap into EXERCISM_STUB_WORKSPACE the way the real CLI
# lays an exercise out, and logs every call.
STUB = r'''#!/bin/sh
printf '%s\n' "$*" >> "$EXERCISM_STUB_LOG"
case "$1" in
configure)
	printf '{"token":"synthetic","workspace":"%s"}' "$3" > "$EXERCISM_CONFIG_HOME/user.json" ;;
version)
	echo "exercism version 9.9.9" ;;
download)
	track=${2#--track=}
	slug=${3#--exercise=}
	if [ "$slug" != leap ]; then echo "Error: no exercise $slug" >&2; exit 1; fi
	dir="$EXERCISM_STUB_WORKSPACE/$track/$slug"
	mkdir -p "$dir/.exercism"
	cp "$EXERCISM_STUB_FILES/leap.odin" "$EXERCISM_STUB_FILES/leap_test.odin" "$dir/"
	printf '{"files":{"solution":["leap.odin"],"test":["leap_test.odin"]}}' > "$dir/.exercism/config.json"
	printf '{"track":"%s","exercise":"%s"}' "$track" "$slug" > "$dir/.exercism/metadata.json"
	echo "$dir" ;;
submit)
	[ -f "$2" ] || exit 1
	echo "Your solution has been submitted successfully." ;;
esac
exit "${EXERCISM_STUB_EXIT:-0}"
'''

WRONG_LEAP = "package leap\n\nis_leap_year :: proc(year: int) -> bool {\n\treturn year % 4 == 0\n}\n"
RIGHT_LEAP = "package leap\n\nis_leap_year :: proc(year: int) -> bool {\n\treturn year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)\n}\n"
LEAP_TESTS = '''package leap

import "core:testing"

@(test)
test_divisible_by_4 :: proc(t: ^testing.T) {
	testing.expect(t, is_leap_year(1996))
}

@(test)
test_divisible_by_100_not_400 :: proc(t: ^testing.T) {
	testing.expect(t, !is_leap_year(1900))
}
'''


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        if self.path != "/odin/main/config.json":
            self.send_response(404)
            self.end_headers()
            return
        body = json.dumps(CATALOGUE).encode()
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main() -> None:
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    checks = 0
    try:
        with tempfile.TemporaryDirectory(prefix="exercism-learning-") as tmp:
            tmp_path = Path(tmp)
            algo = tmp_path / "algo"
            subprocess.run([
                "odin", "build", str(ROOT), f"-out:{algo}",
                f"-define:EXERCISM_TRACKS_URL=http://127.0.0.1:{server.server_port}",
            ], check=True)

            stub_dir = tmp_path / "stub-bin"
            stub_dir.mkdir()
            (stub_dir / "exercism").write_text(STUB)
            (stub_dir / "exercism").chmod(0o755)
            files = tmp_path / "stub-files"
            files.mkdir()
            (files / "leap.odin").write_text(WRONG_LEAP)
            (files / "leap_test.odin").write_text(LEAP_TESTS)
            config_home = tmp_path / "exercism-config"
            config_home.mkdir()
            workspace = tmp_path / "algo-root"
            workspace.mkdir()
            log = tmp_path / "stub.log"
            odin_dir = Path(shutil.which("odin")).parent
            env = dict(
                os.environ,
                PATH=f"{stub_dir}:{odin_dir}:/usr/bin:/bin",
                ALGO_WORKSPACE=str(workspace),
                EXERCISM_CONFIG_HOME=str(config_home),
                EXERCISM_STUB_LOG=str(log),
                EXERCISM_STUB_WORKSPACE=str(workspace / "problems" / "exercism"),
                EXERCISM_STUB_FILES=str(files),
            )
            env.pop("EXERCISM_STUB_EXIT", None)
            env.pop("XDG_CONFIG_HOME", None)

            def judge(*args, expected=0):
                nonlocal checks
                result = subprocess.run([str(algo), "judge", "exercism", *args], cwd=tmp_path, text=True, capture_output=True, timeout=30, env=env)
                checks += 1
                assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
                return result

            def call(operation, payload, expected=0):
                nonlocal checks
                result = subprocess.run(
                    [str(algo), "learn", "call", operation, "--input", "-", "--json"],
                    input=json.dumps(payload), cwd=tmp_path, text=True, capture_output=True, timeout=120, env=env,
                )
                checks += 1
                assert result.returncode == expected, (operation, result.returncode, result.stdout, result.stderr)
                return json.loads(result.stdout)

            def stub_calls():
                return log.read_text().splitlines() if log.exists() else []

            # The catalogue: practice exercises students can start, easiest first.
            judge("setup")
            listed = json.loads(judge("list", "--json").stdout)
            assert [e["slug"] for e in listed["exercises"]] == ["leap", "isogram", "difference-of-squares"]
            assert listed["exercises"][0] == {"slug": "leap", "name": "Leap", "difficulty": 1, "downloaded": False}
            cache = workspace / "problems" / "exercism" / ".cache" / "odin.json"
            assert json.loads(cache.read_text())["track"] == "odin"
            assert json.loads(judge("list", "--offline", "--json").stdout) == listed
            assert "Leap" in judge("list").stdout
            judge("list", "--track", "cobol", expected=1)
            judge("list", "--track", "../odin", expected=2)
            judge("list", "--track", "rust", "--offline", expected=1)

            revision = 0

            def mutate(operation, payload, expected=0):
                nonlocal revision
                envelope = call(operation, dict(payload, request_id=f"{operation}-{revision}", expected_revision=revision), expected)
                revision = envelope["workspace_revision"]
                return envelope

            mutate("workspace_init", {
                "goal": "foundations", "language": "odin", "timezone": "UTC",
                "experience": "beginner", "time_budget_minutes": 30,
            })
            doctor = call("doctor", {})
            exercism = next(p for p in doctor["data"]["providers"] if p["provider"] == "exercism")
            assert exercism["available"] is True and exercism["version"] == "exercism version 9.9.9"

            # plan_next names concrete exercises the track has, easiest first.
            plan = call("plan_next", {"provider": "exercism", "topic": "math-geometry"})
            problems = [c for c in plan["data"]["candidates"] if c["kind"] == "problem"]
            assert [c["problem_key"] for c in problems] == ["exercism:leap", "exercism:difference-of-squares"], problems
            assert problems[0]["name"] == "Leap" and problems[0]["difficulty"] == 1
            assert not plan["warnings"]
            # A concept without mapped exercises moves on to the next one that has some.
            fallback = call("plan_next", {"provider": "exercism", "topic": "tries"})
            moved = [c for c in fallback["data"]["candidates"] if c["kind"] == "problem"]
            assert [c["problem_key"] for c in moved] == ["exercism:leap", "exercism:difference-of-squares"], moved
            assert moved[0]["concept"] == "math-geometry" and "tries maps no unpassed exercism problem" in moved[0]["reason"]
            # Without the cached catalogue, mapped exercises come unfiltered, with a warning.
            cache.rename(cache.with_suffix(".bak"))
            uncached = call("plan_next", {"provider": "exercism", "topic": "binary-search"})
            assert [c["problem_key"] for c in uncached["data"]["candidates"] if c["kind"] == "problem"] == ["exercism:binary-search"]
            assert "not cached" in uncached["warnings"][0]
            cache.with_suffix(".bak").rename(cache)
            call("plan_next", {"provider": "codeforces"}, expected=2)

            session = mutate("session_start", {"objective": "leap years", "mode": "guided", "concept_ids": ["math-geometry"]})
            session_id = session["data"]["session_id"]

            # attempt_start downloads the exercise through the provider, once.
            request = {"session_id": session_id, "problem_key": "exercism:leap", "language": "odin",
                       "request_id": "attempt-leap", "expected_revision": revision}
            attempt = call("attempt_start", request)
            revision = attempt["workspace_revision"]
            assert attempt["data"]["source_path"] == "problems/exercism/odin/leap/leap.odin"
            assert attempt["data"]["runner_kind"] == "odin_test_package"
            assert [c for c in stub_calls() if c.startswith("download")] == ["download --track=odin --exercise=leap"]
            replayed = call("attempt_start", request)
            assert replayed["data"]["attempt_id"] == attempt["data"]["attempt_id"]
            assert len([c for c in stub_calls() if c.startswith("download")]) == 1
            again = call("attempt_start", dict(request, request_id="attempt-leap-2", expected_revision=revision), expected=2)
            assert again["error"]["code"] == "destination_exists" and "register_existing" in again["next_actions"][0]
            missing = call("attempt_start", dict(request, problem_key="exercism:sieve", request_id="attempt-sieve", expected_revision=revision), expected=1)
            assert "download failed" in missing["error"]["message"]
            assert not (workspace / "problems" / "exercism" / "odin" / "sieve").exists()
            attempt_id = attempt["data"]["attempt_id"]
            solution = workspace / attempt["data"]["source_path"]
            tests = solution.parent / "leap_test.odin"

            # test_run runs the exercise's own tests; each is verified evidence.
            failed = mutate("test_run", {"attempt_id": attempt_id}, expected=3)
            assert failed["data"]["outcome"] == "failed"
            assert failed["data"]["verified_passed"] == 1 and failed["data"]["verified_failed"] == 1
            assert {c["provenance"] for c in failed["data"]["cases"]} == {"official_tests"}
            solution.write_text(RIGHT_LEAP)
            passed = mutate("test_run", {"attempt_id": attempt_id})
            assert passed["data"]["outcome"] == "passed" and passed["data"]["verified_passed"] == 2
            assert passed["data"]["tests_modified"] is False
            # Editing the tests makes a run unverified until they are restored.
            tests.write_text(LEAP_TESTS + "\n// edited\n")
            edited = mutate("test_run", {"attempt_id": attempt_id}, expected=4)
            assert edited["data"]["outcome"] == "unverified" and edited["data"]["tests_modified"] is True
            tests.write_text(LEAP_TESTS)
            solution.write_text("package leap\n\nis_leap_year :: proc(year: int) -> bool {\n\treturn nope\n}\n")
            broken = mutate("test_run", {"attempt_id": attempt_id}, expected=3)
            assert broken["data"]["outcome"] == "compile_error"
            solution.write_text(RIGHT_LEAP)

            # A passed exercise is not suggested again.
            plan = call("plan_next", {"provider": "exercism", "topic": "math-geometry"})
            assert [c["problem_key"] for c in plan["data"]["candidates"] if c["kind"] == "problem"] == ["exercism:difference-of-squares"]

            # Sending uploads the exercise file; there is no verdict to wait for.
            intent = mutate("submission_prepare", {"attempt_id": attempt_id})
            sent = mutate("submission_send", {"intent_id": intent["data"]["intent_id"], "authorization_reference": "learner said submit"})
            assert sent["status"] == "completed" and sent["data"]["state"] == "uploaded"
            assert stub_calls()[-1] == f"submit {solution}"
            checked = call("job_check", {"job_id": sent["data"]["job_id"], "request_id": "check-1", "expected_revision": revision}, expected=1)
            assert checked["error"]["code"] == "unsupported_capability"
            progress = call("progress_get", {})
            assert progress["data"]["judge"]["uploaded"] == 1 and progress["data"]["judge"]["pending"] == 0
            resumed = call("session_resume", {"session_id": session_id})
            assert resumed["data"]["handoff"]["pending_jobs"] == []

            # A rejected upload is reported and recorded as not sent.
            solution.write_text(RIGHT_LEAP + "// iteration 2\n")
            intent = mutate("submission_prepare", {"attempt_id": attempt_id})
            env["EXERCISM_STUB_EXIT"] = "1"
            rejected = mutate("submission_send", {"intent_id": intent["data"]["intent_id"], "authorization_reference": "again"}, expected=1)
            assert "did not accept the upload" in rejected["error"]["message"]
            del env["EXERCISM_STUB_EXIT"]
            print(f"PASS: {checks} Exercism learning-engine checks (stub CLI, fixture catalogue)")
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
