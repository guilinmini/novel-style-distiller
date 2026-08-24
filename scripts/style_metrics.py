#!/usr/bin/env python3
"""Profile Chinese prose shape and compare it with source-neutral style targets."""

from __future__ import annotations

import argparse
import json
import re
import statistics
import sys
from pathlib import Path
from typing import Any


SENTENCE_END = re.compile(r"(?<=[。！？!?])")
DIALOGUE_MARKS = ("“", "”", "「", "」", "『", "』", '"')


def read_text(paths: list[Path]) -> str:
    parts: list[str] = []
    for path in paths:
        text = path.read_text(encoding="utf-8")
        body_lines = [line for line in text.splitlines() if not line.lstrip().startswith("#")]
        parts.append("\n".join(body_lines))
    return "\n\n".join(parts)


def percentile(values: list[int], fraction: float) -> float:
    if not values:
        return 0.0
    ordered = sorted(values)
    index = max(0, min(len(ordered) - 1, int((len(ordered) - 1) * fraction + 0.999999)))
    return float(ordered[index])


def compact_len(text: str) -> int:
    return len(re.sub(r"\s+", "", text))


def profile_text(text: str, short_threshold: int = 35, long_threshold: int = 80) -> dict[str, Any]:
    paragraphs = [line.strip() for line in text.splitlines() if line.strip()]
    paragraph_lengths = [compact_len(line) for line in paragraphs]
    compact = re.sub(r"\s+", "", text)
    sentences = [part for part in SENTENCE_END.split(text) if part.strip()]
    sentence_lengths = [compact_len(part) for part in sentences]
    dialogue_count = sum(any(mark in paragraph for mark in DIALOGUE_MARKS) for paragraph in paragraphs)
    total_chars = len(compact)

    def ratio(count: int, total: int) -> float:
        return round(count / total, 6) if total else 0.0

    per_1000_base = total_chars / 1000 if total_chars else 1
    return {
        "characters_no_whitespace": total_chars,
        "paragraphs": len(paragraphs),
        "sentences": len(sentences),
        "mean_paragraph_chars": round(statistics.mean(paragraph_lengths), 3) if paragraph_lengths else 0.0,
        "median_paragraph_chars": round(statistics.median(paragraph_lengths), 3) if paragraph_lengths else 0.0,
        "p75_paragraph_chars": round(percentile(paragraph_lengths, 0.75), 3),
        "p90_paragraph_chars": round(percentile(paragraph_lengths, 0.90), 3),
        "short_paragraph_threshold_chars": short_threshold,
        "short_paragraph_ratio": ratio(sum(length <= short_threshold for length in paragraph_lengths), len(paragraph_lengths)),
        "long_paragraph_threshold_chars": long_threshold,
        "long_paragraph_ratio": ratio(sum(length >= long_threshold for length in paragraph_lengths), len(paragraph_lengths)),
        "mean_sentence_chars": round(statistics.mean(sentence_lengths), 3) if sentence_lengths else 0.0,
        "dialogue_paragraph_ratio": ratio(dialogue_count, len(paragraphs)),
        "ellipsis_per_1000_chars": round(compact.count("……") / per_1000_base, 3),
        "question_per_1000_chars": round((compact.count("？") + compact.count("?")) / per_1000_base, 3),
    }


def classify(value: float, target: list[float], hard: list[float]) -> str:
    if target[0] <= value <= target[1]:
        return "PASS"
    if hard[0] <= value <= hard[1]:
        return "WARN"
    return "FAIL"


def compare(profile: dict[str, Any], targets: dict[str, Any], text: str) -> dict[str, Any]:
    results: dict[str, Any] = {}
    statuses: list[str] = []
    for metric, spec in targets.get("metrics", {}).items():
        if metric not in profile:
            results[metric] = {"status": "NOT_MEASURED"}
            continue
        value = float(profile[metric])
        status = classify(value, spec["target"], spec["hard"])
        statuses.append(status)
        results[metric] = {
            "value": value,
            "target": spec["target"],
            "hard": spec["hard"],
            "status": status,
        }

    compact = re.sub(r"\s+", "", text)
    per_10000_base = len(compact) / 10000 if compact else 1
    lexical_results: dict[str, Any] = {}
    for signal_id, spec in targets.get("lexical_signals", {}).items():
        terms = [term for term in spec.get("terms", []) if term]
        count = sum(compact.count(term) for term in terms)
        value = round(count / per_10000_base, 3)
        target_range = spec["target_per_10000_chars"]
        hard_range = spec["hard_per_10000_chars"]
        status = classify(value, target_range, hard_range)
        statuses.append(status)
        lexical_results[signal_id] = {
            "value_per_10000_chars": value,
            "count": count,
            "target": target_range,
            "hard": hard_range,
            "status": status,
        }

    overall = "FAIL" if "FAIL" in statuses else "WARN" if "WARN" in statuses else "PASS"
    return {"overall": overall, "metrics": results, "lexical_signals": lexical_results}


def main() -> int:
    parser = argparse.ArgumentParser()
    subparsers = parser.add_subparsers(dest="command", required=True)
    profile_parser = subparsers.add_parser("profile")
    profile_parser.add_argument("files", nargs="+", type=Path)
    profile_parser.add_argument("--short-threshold", type=int, default=35)
    profile_parser.add_argument("--long-threshold", type=int, default=80)
    compare_parser = subparsers.add_parser("compare")
    compare_parser.add_argument("--targets", required=True, type=Path)
    compare_parser.add_argument("files", nargs="+", type=Path)
    args = parser.parse_args()

    text = read_text(args.files)
    if args.command == "profile":
        result = profile_text(text, args.short_threshold, args.long_threshold)
        print(json.dumps(result, ensure_ascii=False, indent=2))
        return 0

    targets = json.loads(args.targets.read_text(encoding="utf-8"))
    short_threshold = int(targets.get("metrics", {}).get("short_paragraph_ratio", {}).get("threshold_chars", 35))
    long_threshold = int(targets.get("metrics", {}).get("long_paragraph_ratio", {}).get("threshold_chars", 80))
    profile = profile_text(text, short_threshold, long_threshold)
    result = {"profile": profile, "comparison": compare(profile, targets, text)}
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return {"PASS": 0, "WARN": 1, "FAIL": 2}[result["comparison"]["overall"]]


if __name__ == "__main__":
    sys.exit(main())
