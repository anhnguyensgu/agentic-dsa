"""Exercise the compiled Odin CLI against an isolated HTTP service and filesystem.

No real cookies, account changes, or remote submissions. Requires Odin + curl.
"""
import copy
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

ROOT = Path(__file__).resolve().parents[1]
PROBLEM = {
    "questionId": "1", "questionFrontendId": "1", "title": "Two Sum",
    "titleSlug": "two-sum", "difficulty": "Easy", "isPaidOnly": False,
    "content": "<p>Two sum.</p><pre>Output: [0,1]\n</pre><pre>Output: [1,2]\n</pre>",
    "sampleTestCase": "[2,7,11,15]\n9",
    "exampleTestcaseList": ["[2,7,11,15]\n9", "[3,2,4]\n6"],
    "metaData": json.dumps({"name": "twoSum", "params": [
        {"name": "nums", "type": "integer[]"}, {"name": "target", "type": "integer"}],
        "return": {"type": "integer[]"}}),
    "codeSnippets": [{"lang": "Python3", "langSlug": "python3", "code": "class Solution:\n    pass"}],
    "topicTags": [{"name": "Array", "slug": "array"}],
}
REQUESTS = []
POLL_COUNTS = {}
JOBS = {}


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def reply(self, data, status=200):
        body = json.dumps(data).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        REQUESTS.append((self.path, body, dict(self.headers)))
        if self.path == "/graphql/":
            query, variables = body["query"], body.get("variables", {})
            if "userStatus" in query:
                valid = "synthetic-session" in self.headers.get("Cookie", "")
                return self.reply({"data": {"userStatus": {"username": "tester" if valid else None,
                                                         "isSignedIn": valid, "isPremium": False}}})
            if "questionList(" in query:
                paid = dict(PROBLEM, titleSlug="paid-problem", isPaidOnly=True)
                free = dict(PROBLEM, titleSlug="another-free", questionFrontendId="2")
                catalogue = [PROBLEM, paid, free]
                offset = variables.get("skip", 0)
                # A small server-side page cap exercises pagination independently
                # of the client's requested limit.
                size = min(variables.get("limit", 20), 2)
                return self.reply({"data": {"problemsetQuestionList": {
                    "total": len(catalogue), "questions": catalogue[offset:offset+size]}}})
            if "activeDailyCodingChallengeQuestion" in query:
                return self.reply({"data": {"activeDailyCodingChallengeQuestion": {
                    "date": "2026-09-19", "question": {"titleSlug": "two-sum"}}}})
            if "questionSubmissionList" in query:
                return self.reply({"data": {"questionSubmissionList": {"hasNext": False, "submissions": [
                    {"id": "123", "statusDisplay": "Accepted", "lang": "python3", "runtime": "1 ms", "memory": "1 MB"}]}}})
            if "submissionDetails" in query:
                return self.reply({"data": {"submissionDetails": {"id": 123, "statusCode": 10, "code": "source"}}})
            if "matchedUser" in query:
                return self.reply({"data": {"matchedUser": {"username": "tester", "profile": {"ranking": 1},
                    "submitStatsGlobal": {"acSubmissionNum": [{"difficulty": "All", "count": 2}]}}}})
            if "question(titleSlug:" in query:
                slug = variables["slug"]
                if slug == "blocked":
                    return self.reply({}, 403)
                if slug == "rate-limited":
                    return self.reply({}, 429)
                if slug == "broken":
                    return self.reply({"errors": [{"message": "bad query"}]})
                if slug == "missing":
                    return self.reply({"data": {"question": None}})
                q = copy.deepcopy(PROBLEM)
                q["titleSlug"] = slug
                if slug == "generic":
                    q["metaData"] = json.dumps({"systemdesign": True})
                    q["exampleTestcaseList"] = ['["Counter","add"]\n[[],[2]]']
                    q["content"] = "<pre>Output: [null,2]\n</pre>"
                if slug == "in-place":
                    q["metaData"] = json.dumps({"name": "rotate", "params": [
                        {"name": "matrix", "type": "integer[][]"}], "return": {"type": "void"}})
                    q["exampleTestcaseList"] = ["[[1,2],[3,4]]"]
                    q["content"] = "<pre>Output: [[4,2],[3,1]]\n</pre>"
                if slug == "mixed-types":
                    q["metaData"] = json.dumps({"name": "mix", "params": [
                        {"name": "names", "type": "string[]"},
                        {"name": "active", "type": "boolean"},
                        {"name": "value", "type": "double"}], "return": {"type": "double"}})
                    q["exampleTestcaseList"] = ['["a","b"]\ntrue\n2.5']
                    q["content"] = "<pre>Output: 5.0\n</pre>"
                return self.reply({"data": {"question": q}})
        if self.path.endswith(("/submit/", "/interpret_solution/")):
            assert self.headers.get("x-csrftoken") == "synthetic-csrf"
            assert "synthetic-session" in self.headers.get("Cookie", "")
            assert body["lang"] == "python3" and body["question_id"] == "1"
            job = str(1000 + len(JOBS)) if self.path.endswith("/submit/") else f"runcode_1234.{len(JOBS)}_abc"
            JOBS[job] = body["typed_code"]
            key = "submission_id" if self.path.endswith("/submit/") else "interpret_id"
            return self.reply({key: int(job) if key == "submission_id" else job})
        self.reply({}, 404)

    def do_GET(self):
        REQUESTS.append((self.path, None, dict(self.headers)))
        if self.path.startswith("/submissions/detail/") and self.path.endswith("/check/"):
            job = self.path.split("/")[3]
            POLL_COUNTS[job] = POLL_COUNTS.get(job, 0) + 1
            if job == "pending" or POLL_COUNTS[job] == 1:
                return self.reply({"state": "PENDING"})
            source = JOBS.get(job, "accepted")
            result = {"state": "SUCCESS", "status_code": 10, "status_msg": "Accepted",
                      "status_runtime": "1 ms", "status_memory": "1 MB", "correct_answer": True}
            if "wrong" in source:
                result["correct_answer"] = False
            if "compile-error" in source:
                result.update(status_code=20, status_msg="Compile Error", compile_error="invalid syntax")
            return self.reply(result)
        self.reply({}, 404)


def main():
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    checks = 0
    try:
        with tempfile.TemporaryDirectory(prefix="leetcode-integration-") as temp:
            temp = Path(temp)
            algo = temp / "algo"
            subprocess.run(["odin", "build", str(ROOT), f"-out:{algo}",
                            f"-define:LEETCODE_BASE_URL=http://127.0.0.1:{server.server_port}"], check=True)
            config, workspace = temp / "auth" / "config.json", temp / "workspace"
            env = dict(os.environ, LEETCODE_ODIN_CONFIG=str(config),
                       LEETCODE_ODIN_WORKSPACE=str(workspace), LEETCODE_ODIN_NO_BROWSER="1")

            def cli(*args, expected=0, stdin=None):
                nonlocal checks
                result = subprocess.run([str(algo), "judge", "leetcode", *map(str, args)], env=env, text=True,
                                        input=stdin, capture_output=True, timeout=30)
                checks += 1
                assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
                assert "synthetic-session" not in result.stdout + result.stderr
                assert "synthetic-csrf" not in result.stdout + result.stderr
                return result

            cli("help")
            cli("version")
            cli("show", expected=2)
            cli("list", "--wat", expected=2)
            cli("status", expected=1)
            cli("paste", stdin="invalid-session\n", expected=1)
            assert not config.exists()
            cli("paste", stdin="LEETCODE_SESSION=synthetic-session; csrftoken=synthetic-csrf\n")
            assert config.stat().st_mode & 0o777 == 0o600
            cli("status")
            assert json.loads(cli("status", "--json").stdout)["signed_in"] is True
            cli("show", "two-sum", "--lang", "odin", expected=2)
            listed = json.loads(cli("list", "two sum", "--tag", "array", "--difficulty", "Easy",
                                    "--free", "--limit", "1", "--json").stdout)
            assert listed["questions"][0]["titleSlug"] == "two-sum"
            filters = REQUESTS[-1][1]["variables"]["filters"]
            assert filters["difficulty"] == "EASY" and filters["tags"] == ["array"]
            assert listed["total"] == 2 and len(listed["questions"]) == 1
            page = json.loads(cli("list", "two sum", "--free", "--skip", "1", "--limit", "1", "--json").stdout)
            assert page["questions"][0]["titleSlug"] == "another-free"
            count = len(REQUESTS)
            cli("list", "two sum", "--tag", "array", "--difficulty", "Easy", "--free", "--limit", "1", "--offline")
            assert len(REQUESTS) == count
            cli("list", "--status", "notac")
            assert REQUESTS[-1][1]["variables"]["filters"]["status"] == "TRIED"
            cli("list", "--status", "todo")
            assert REQUESTS[-1][1]["variables"]["filters"]["status"] == "NOT_STARTED"
            cli("show", "1")
            assert json.loads(cli("show", "https://leetcode.com/problems/two-sum/description/", "--json").stdout)["questionId"] == "1"
            cli("show", "two-sum", "--offline")
            cache = workspace / ".cache" / "problem-two-sum.json"
            cached_text = cache.read_text()
            cache.write_text('{"titleSlug":"two-sum"}')
            cli("show", "two-sum", "--offline", expected=1)
            cache.write_text(cached_text)
            cli("show", "two-sum", "--refresh")
            cli("show", "uncached", "--offline", expected=1)
            for slug in ("missing", "broken", "blocked", "rate-limited"):
                cli("show", slug, expected=1)
            cli("show", "../secrets", expected=2)
            cli("daily")
            cli("daily", "--offline")
            cli("random")
            cli("random", "--offline", "--difficulty", "Easy", "--tag", "array")
            cli("languages", "two-sum")
            cli("open", "two-sum")
            selected = json.loads(cli("get", "two-sum", "--json").stdout)
            local = Path(selected["directory"])
            original = (local / "solution.odin").read_text()
            cli("pick", "two-sum", expected=1)
            assert (local / "solution.odin").read_text() == original
            assert len(json.loads((local / "cases.json").read_text())) == 2
            (local / "solution.odin").write_text('''package main
solve :: proc(nums: []int, target: int) -> []int {
    for x, i in nums { for j := i+1; j < len(nums); j += 1 {
        if x + nums[j] == target {
            answer := make([]int,2)
            answer[0], answer[1] = i, j
            return answer
        }
    } }
    return nil
}
''')
            assert "2/2 checked cases passed" in cli("test", local).stdout
            structured_local = json.loads(cli("test", local, "--json").stdout)
            assert structured_local["outcome"] == "passed"
            assert structured_local["verified_passed"] == 2
            cases = json.loads((local / "cases.json").read_text())
            cases[0]["expected"] = [9, 9]
            (local / "cases.json").write_text(json.dumps(cases))
            cli("test", local, expected=3)
            cases[0]["expected"] = [1, 0]
            cases[0]["unordered"] = True
            (local / "cases.json").write_text(json.dumps(cases))
            cli("test", local)
            cases[0]["check"] = False
            (local / "cases.json").write_text(json.dumps(cases))
            cli("test", local, expected=4)
            (local / "solution.odin").write_text("package main\nsolve :: proc(a: []int,b:int)->[]int { for {} }\n")
            cli("test", local, "--timeout", "1", expected=1)
            generic = Path(json.loads(cli("pick", "generic", "--json").stdout)["directory"])
            (generic / "solution.odin").write_text('''package main
import "core:encoding/json"
solve :: proc(input: []json.Value) -> json.Value {
    return json.parse(`[null,2]`, .JSON, parse_integers=true) or_else nil
}
''')
            cli("test", generic)
            in_place = Path(json.loads(cli("pick", "in-place", "--json").stdout)["directory"])
            (in_place / "solution.odin").write_text('''package main
solve :: proc(grid: [][]int) { grid[0][0], grid[1][1] = grid[1][1], grid[0][0] }
''')
            cli("test", in_place)
            mixed = Path(json.loads(cli("pick", "mixed-types", "--json").stdout)["directory"])
            (mixed / "solution.odin").write_text('''package main
solve :: proc(names: []string, active: bool, value: f64) -> f64 {
    if active { return f64(len(names)) * value }
    return 0
}
''')
            cli("test", mixed)
            (mixed / "cases.json").write_text("[]")
            cli("test", mixed, expected=3)
            py = Path(json.loads(cli("pick", "two-sum", "--lang", "python3", "--json").stdout)["directory"]) / "solution.py"
            py.write_text("# accepted\n")
            result = json.loads(cli("run", "two-sum", py, "--json").stdout)
            assert result["status_code"] == 10
            custom = temp / "input with spaces.txt"
            custom.write_text("[1,2]\n3")
            cli("run", "two-sum", py, "--input", custom)
            requests = [r for r in REQUESTS if r[0].endswith("/interpret_solution/")]
            assert requests[-1][1]["data_input"] == "[1,2]\n3"
            started = json.loads(cli("submit-start", "two-sum", py, "--json").stdout)
            assert started["state"] == "queued" and started["operation"] == "submission"
            cli("check", started["job_id"])
            cli("submit", "two-sum", py)
            py.write_text("# wrong\n")
            cli("run", "two-sum", py, expected=3)
            py.write_text("# compile-error\n")
            cli("submit", "two-sum", py, expected=3)
            cli("run", "two-sum", local / "solution.odin", expected=1)
            cli("check", "123")
            cli("watch", "123")
            cli("check", "pending", "--timeout", "1", expected=1)
            cli("check", "../bad", expected=2)
            cli("submissions", "two-sum")
            cli("submission", "123")
            cli("stats")
            cli("stats", "tester", "--json")
            cli("logout")
            cli("logout")
            assert not config.exists()
            cli("submit", "two-sum", py, expected=1)
            cli("stats", "tester")
            print(f"PASS: {checks} CLI integration checks (no real submissions)")
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
