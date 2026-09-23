#!/usr/bin/env python3
"""Validate the reviewed tutor scenarios against the shipped skill and registry."""

import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    document = json.loads((ROOT / "tests" / "teaching" / "scenarios.json").read_text())
    scenarios = document["scenarios"]
    assert document["schema_version"] == 1 and len(scenarios) >= 9
    ids = [scenario["id"] for scenario in scenarios]
    assert len(ids) == len(set(ids))
    registry_source = (ROOT / "algolearn" / "learning" / "handlers.odin").read_text()
    registered = set(re.findall(r'name = "([a-z_]+)"', registry_source))
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
