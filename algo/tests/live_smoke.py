"""Public API smoke tests; --account adds private reads, --run interprets examples.

Never submits a solution. Uses a temporary workspace and leaves credentials intact.
"""
import argparse
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--account", action="store_true")
    parser.add_argument("--run", action="store_true")
    opts = parser.parse_args()
    algo = ROOT / "bin" / "algo"
    with tempfile.TemporaryDirectory(prefix="leetcode-live-") as temp:
        env = dict(os.environ, LEETCODE_ODIN_WORKSPACE=temp, LEETCODE_ODIN_NO_BROWSER="1")
        if not (opts.account or opts.run):
            env["LEETCODE_ODIN_CONFIG"] = str(Path(temp) / "no-credentials.json")

        def read(*args):
            result = subprocess.run([str(algo), "judge", "leetcode", *args, "--json"], env=env,
                                    text=True, capture_output=True, timeout=90)
            if result.returncode:
                raise RuntimeError(f"{args[0]} failed: {result.stderr}")
            return json.loads(result.stdout)

        assert read("list", "two sum", "--limit", "2")["total"] > 0
        free = read("list", "two sum", "--free", "--limit", "10")
        assert free["questions"] and all(not q["isPaidOnly"] for q in free["questions"])
        assert read("show", "1")["titleSlug"] == "two-sum"
        assert read("show", "two-sum", "--offline")["questionId"] == "1"
        assert read("daily")["titleSlug"]
        picked = read("random", "--free", "--difficulty", "Easy")
        assert picked["difficulty"] == "Easy" and not picked["isPaidOnly"]
        assert any(x["langSlug"] == "python3" for x in read("languages", "two-sum"))
        read("pick", "two-sum")
        print("PASS: public discovery, ID lookup, offline cache, daily/random, languages, scaffold")
        if opts.account:
            assert read("status")["signed_in"]
            for status in ("ac", "notac", "todo"):
                assert "questions" in read("list", "--status", status, "--limit", "1")
            assert read("stats")["username"]
            history = read("submissions", "two-sum", "--limit", "1")
            if history["submissions"]:
                assert read("submission", str(history["submissions"][0]["id"]))["code"]
            print("PASS: session, progress filters, statistics, submission history/details")
        if opts.run:
            result = read("run", "two-sum", str(ROOT / "tests" / "fixtures" / "two_sum.py"))
            assert result["status_code"] == 10
            print("PASS: live example interpretation (no submission created)")


if __name__ == "__main__":
    main()
