#!/usr/bin/env python3
"""Fixture-controlled Kattis provider contract and bounded runner checks."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import subprocess
import tempfile
import threading

ROOT = Path(__file__).resolve().parents[1]

LIST_HTML = '''<table><thead><tr><th data-name="title_link">Problem</th></tr></thead><tbody>
<tr><td><a href="/problems/twostones">Two Stones</a></td><td>-</td><td>100</td><td>80</td><td>-</td><td>80%</td><td>1.3 Easy</td></tr>
</tbody></table>'''
SEARCH_HTML = '''<h2>Problems</h2><table><tr><td><a href="/problems/twostones">twostones</a></td><td>Two Stones</td></tr></table>'''
SHOW_HTML = '''<html><head><title>Two Stones – Kattis, Kattis</title></head><body>
<span class="difficulty_number-problem_view">1.3</span><span class="info_label">Difficulty</span><span class="text-link">Easy</span>
<div class="problembody"><p>Print Alice for odd values and Bob for even values.</p></div>
<table class="sample"><tr><td><pre>\n1\n</pre></td><td><pre>\nAlice\n</pre></td></tr></table>
</body></html>'''


class Handler(BaseHTTPRequestHandler):
    def log_message(self, *_):
        pass

    def do_GET(self):
        if self.path.startswith("/problems?"):
            body = LIST_HTML
        elif self.path.startswith("/search?"):
            body = SEARCH_HTML
        elif self.path == "/problems/twostones":
            body = SHOW_HTML
        else:
            self.send_response(404)
            self.end_headers()
            return
        encoded = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/html")
        self.send_header("Content-Length", str(len(encoded)))
        self.end_headers()
        self.wfile.write(encoded)


def main() -> None:
    server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    checks = 0
    try:
        with tempfile.TemporaryDirectory(prefix="kattis-integration-") as tmp:
            tmp_path = Path(tmp)
            binary = tmp_path / "kattis"
            subprocess.run([
                "odin", "build", str(ROOT / "kattis"), f"-out:{binary}",
                f"-define:KATTIS_BASE_URL=http://127.0.0.1:{server.server_port}",
            ], check=True)

            def cli(*args, expected=0, timeout=30, extra_env=None):
                nonlocal checks
                env = dict(os.environ)
                if extra_env:
                    env.update(extra_env)
                result = subprocess.run([str(binary), *map(str, args)], cwd=tmp_path, text=True, capture_output=True, timeout=timeout, env=env)
                checks += 1
                assert result.returncode == expected, (args, result.returncode, result.stdout, result.stderr)
                return result

            cli("help")
            assert cli("version").stdout.strip() == "kattis-odin 0.2.0"
            assert json.loads(cli("capabilities", "--json").stdout)["local_test"]["json_report"] is True
            listed = json.loads(cli("list", "0", "--json").stdout)
            assert listed["count"] == 1 and listed["problems"][0]["id"] == "twostones"
            searched = json.loads(cli("search", "stones", "--json").stdout)
            assert searched["problems"][0]["problem_key"] == "kattis:twostones"
            shown = json.loads(cli("show", "twostones", "--json").stdout)
            assert shown["problem_key"] == "kattis:twostones" and shown["samples"][0]["provenance"] == "official_sample"

            destination = tmp_path / "fresh attempt"
            created = json.loads(cli("get", "twostones", "--dir", destination, "--json").stdout)
            assert Path(created["directory"]) == destination
            original = (destination / "solution.odin").read_bytes()
            cli("get", "twostones", "--dir", destination, "--json", expected=1)
            assert (destination / "solution.odin").read_bytes() == original

            (destination / "solution.odin").write_text('''package main
import "core:fmt"
main :: proc() { fmt.println("Alice") }
''')
            report = json.loads(cli("test", destination, "--json").stdout)
            assert report["outcome"] == "passed" and report["verified_passed"] == 1

            (destination / "solution.odin").write_text('''package main
import "core:fmt"
import "core:os"
main :: proc() { fmt.println(os.get_env("LEETCODE_SESSION", context.allocator)) }
''')
            (destination / "samples" / "sample1.out").write_text("\n")
            scrubbed = json.loads(cli("test", destination, "--json", extra_env={"LEETCODE_SESSION": "synthetic-secret"}).stdout)
            assert scrubbed["outcome"] == "passed" and "synthetic-secret" not in json.dumps(scrubbed)

            (destination / "solution.odin").write_text('''package main
import "core:fmt"
main :: proc() { for { fmt.println("unbounded learner output") } }
''')
            limited = cli("test", destination, "--json", expected=1, timeout=15)
            limited_report = json.loads(limited.stdout)
            assert limited_report["outcome"] == "failed"
            assert limited_report["cases"][0]["output_limit_exceeded"] is True

            cli("show", "../secret", expected=1)
            cli("list", "bad-page", expected=1)
            print(f"PASS: {checks} Kattis fixture and bounded-runner checks")
    finally:
        server.shutdown()
        server.server_close()


if __name__ == "__main__":
    main()
