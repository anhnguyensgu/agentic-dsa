#!/usr/bin/env python3
"""Validate the reviewed tutor scenarios against the shipped skill and registry."""

import json
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
BINARY = ROOT / "bin" / "algolearn"


def registered_operations() -> set[str]:
    """Ask the built engine for its operation registry over MCP."""
    messages = [
        {"jsonrpc": "2.0", "id": 1, "method": "initialize", "params": {"protocolVersion": "2025-11-25"}},
        {"jsonrpc": "2.0", "id": 2, "method": "tools/list", "params": {}},
        {"jsonrpc": "2.0", "method": "exit", "params": {}},
    ]
    with tempfile.TemporaryDirectory(prefix="algolearn-scenarios-") as workspace:
        result = subprocess.run(
            [str(BINARY), "serve", "--workspace", workspace],
            input="".join(json.dumps(m) + "\n" for m in messages),
            text=True, capture_output=True, timeout=30, check=True,
        )
    replies = [json.loads(line) for line in result.stdout.splitlines()]
    tools = next(r for r in replies if r.get("id") == 2)["result"]["tools"]
    return {tool["name"] for tool in tools}


def main() -> None:
    document = json.loads((ROOT / "tests" / "teaching" / "scenarios.json").read_text())
    scenarios = document["scenarios"]
    assert document["schema_version"] == 1 and len(scenarios) >= 9
    ids = [scenario["id"] for scenario in scenarios]
    assert len(ids) == len(set(ids))
    registered = registered_operations()
    skill = (ROOT / "skills" / "algorithm-learning" / "SKILL.md").read_text()
    references = "\n".join(path.read_text() for path in (ROOT / "skills" / "algorithm-learning" / "references").glob("*.md"))
    corpus = (skill + "\n" + references).lower()
    required_topics = ["hint", "independent", "unverified", "checkpoint", "submission", "frustrat", "legacy"]
    assert all(topic in corpus for topic in required_topics)
    for scenario in scenarios:
        assert scenario["prompt"] and len(scenario["expected"]) >= 2
        assert set(scenario["operations"]) <= registered, (scenario["id"], set(scenario["operations"]) - registered)
    print(f"PASS: {len(scenarios)} reviewed teaching/recovery scenario contracts")


if __name__ == "__main__":
    main()
