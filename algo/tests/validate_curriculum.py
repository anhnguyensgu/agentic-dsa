#!/usr/bin/env python3
"""Validate the bundled concept graph. There is no bundled problem set."""

import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TAG = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def main() -> None:
    assert not (ROOT / "curriculum" / "problems.json").exists()
    doc = json.loads((ROOT / "curriculum" / "concepts.json").read_text())
    assert doc["schema_version"] == 1 and doc["curriculum_version"]
    concepts = doc["concepts"]
    ids = {item["id"] for item in concepts}
    assert len(ids) == len(concepts) >= 10
    for concept in concepts:
        assert set(concept["prerequisites"]) <= ids
        assert concept["id"] not in concept["prerequisites"]
        assert concept["outcomes"]
        assert concept["leetcode_tags"] and all(TAG.match(tag) for tag in concept["leetcode_tags"])
    print(f"PASS: {len(concepts)} concepts with prerequisites and provider topic tags")


if __name__ == "__main__":
    main()
