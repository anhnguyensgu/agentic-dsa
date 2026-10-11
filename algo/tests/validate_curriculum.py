#!/usr/bin/env python3
"""Validate the bundled concept graph and reviewed problem mappings."""

import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    concepts_doc = json.loads((ROOT / "curriculum" / "concepts.json").read_text())
    problems_doc = json.loads((ROOT / "curriculum" / "problems.json").read_text())
    assert concepts_doc["schema_version"] == problems_doc["schema_version"] == 1
    concepts = concepts_doc["concepts"]
    problems = problems_doc["problems"]
    ids = {item["id"] for item in concepts}
    assert len(ids) == len(concepts) >= 10
    for concept in concepts:
        assert set(concept["prerequisites"]) <= ids
        assert concept["outcomes"]
    assert len(problems) >= 36
    assert {problem["provider"] for problem in problems} == {"kattis", "leetcode"}
    keys = [problem["problem_key"] for problem in problems]
    assert len(keys) == len(set(keys))
    coverage = {concept_id: 0 for concept_id in ids}
    for problem in problems:
        required = {
            "problem_key", "provider", "native_id", "slug", "title",
            "canonical_url", "difficulty", "concept_ids", "prerequisites",
            "effort_minutes", "spoiler_tags", "access", "practice_modes",
            "judge_languages", "offline", "label_origin",
        }
        assert required <= problem.keys(), (problem["problem_key"], required - problem.keys())
        assert problem["problem_key"] == f'{problem["provider"]}:{problem["slug"]}'
        assert problem["canonical_url"].startswith("https://")
        assert 5 <= problem["effort_minutes"] <= 180
        assert problem["concept_ids"] and set(problem["concept_ids"]) <= ids
        assert set(problem["prerequisites"]) <= ids
        assert problem["label_origin"] == "curated"
        assert "odin_local" in problem["practice_modes"]
        if problem["provider"] == "leetcode":
            assert "odin" not in {lang.lower() for lang in problem["judge_languages"]}
        for concept_id in problem["concept_ids"]:
            coverage[concept_id] += 1
    assert min(coverage.values()) >= 2, coverage
    print(f"PASS: {len(problems)} mappings, {len(concepts)} concepts, minimum coverage {min(coverage.values())}")


if __name__ == "__main__":
    main()
