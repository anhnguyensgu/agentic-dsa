#!/usr/bin/env python3
"""Validate the bundled concept graph. There is no bundled problem set."""

import json
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
SLUG = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")


def main() -> None:
    assert not (ROOT / "curriculum" / "problems.json").exists()
    doc = json.loads((ROOT / "curriculum" / "concepts.json").read_text())
    assert doc["schema_version"] == 1 and doc["curriculum_version"]
    concepts = doc["concepts"]
    ids = [item["id"] for item in concepts]
    assert len(set(ids)) == len(ids) >= 18
    seen: set[str] = set()
    for concept in concepts:
        # Group ids cannot contain "/": that separates a group from its sub-patterns.
        assert SLUG.match(concept["id"]), concept["id"]
        # Prerequisites come earlier, so planning walks the list in study order.
        assert set(concept["prerequisites"]) <= seen, (concept["id"], set(concept["prerequisites"]) - seen)
        assert concept["title"] and concept["outcomes"]
        assert concept["leetcode_tags"] and all(SLUG.match(tag) for tag in concept["leetcode_tags"])
        seen.add(concept["id"])
    print(f"PASS: {len(concepts)} concept groups in prerequisite order with provider topic tags")


if __name__ == "__main__":
    main()
