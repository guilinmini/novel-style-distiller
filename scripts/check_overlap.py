#!/usr/bin/env python3
"""Check generated fiction for suspicious surface overlap with a source novel.

This is a deterministic project quality gate, not a legal test.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
import unicodedata
from pathlib import Path
from typing import Sequence, TypeVar


TEXT_SUFFIXES = {".txt", ".md", ".markdown"}
UNICODE_WORD = re.compile(r"[^\W\d_]+(?:['’][^\W\d_]+)?", re.UNICODE)
NOTICE = "Project quality gate only; not legal advice or a copyright safe-harbor test."
T = TypeVar("T")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def is_cjk(char: str) -> bool:
    code = ord(char)
    return (
        0x3400 <= code <= 0x4DBF
        or 0x4E00 <= code <= 0x9FFF
        or 0xF900 <= code <= 0xFAFF
        or 0x20000 <= code <= 0x2FA1F
    )


def read_source_file(path: Path) -> str:
    """Read exactly one supported source file.

    Treating a directory as a source would silently concatenate editions, notes, or
    unrelated files and make every overlap metric ambiguous, so it is intentionally
    rejected here.
    """
    if not path.exists():
        raise FileNotFoundError(path)
    if not path.is_file():
        raise ValueError(f"source must be one TXT or Markdown file, not a directory: {path}")
    if path.suffix.lower() not in TEXT_SUFFIXES:
        raise ValueError(
            f"unsupported source format {path.suffix!r}; extract complete TXT or Markdown first"
        )
    return path.read_text(encoding="utf-8")


def expand_generated_paths(paths: Sequence[Path]) -> list[Path]:
    """Expand generated inputs into distinct supported files without concatenating them."""
    artifacts: list[Path] = []
    seen: set[Path] = set()
    for path in paths:
        if not path.exists():
            raise FileNotFoundError(path)
        if path.is_file():
            if path.suffix.lower() not in TEXT_SUFFIXES:
                raise ValueError(
                    f"unsupported generated format {path.suffix!r}: {path}; "
                    "use TXT or Markdown"
                )
            candidates = [path]
        elif path.is_dir():
            candidates = [
                child
                for child in sorted(path.rglob("*"))
                if child.is_file() and child.suffix.lower() in TEXT_SUFFIXES
            ]
            if not candidates:
                raise ValueError(f"generated directory contains no TXT or Markdown files: {path}")
        else:
            raise ValueError(f"generated input is not a regular file or directory: {path}")

        for candidate in candidates:
            key = candidate.resolve()
            if key not in seen:
                seen.add(key)
                artifacts.append(candidate)

    if not artifacts:
        raise ValueError("generated input contains no TXT or Markdown files")
    return artifacts


def cjk_stream(text: str) -> str:
    return "".join(char for char in text if is_cjk(char))


def unicode_word_tokens(text: str) -> list[str]:
    tokens: list[str] = []
    for match in UNICODE_WORD.finditer(text):
        token = match.group(0)
        if any(is_cjk(char) for char in token):
            continue
        tokens.append(unicodedata.normalize("NFKC", token).casefold().replace("’", "'"))
    return tokens


def significant_stream(text: str) -> str:
    normalized = unicodedata.normalize("NFKC", text).casefold()
    return "".join(char for char in normalized if char.isalnum())


def longest_cjk_seed_match(source: str, generated: str, seed: int) -> tuple[int, str]:
    if len(source) < seed or len(generated) < seed:
        return 0, ""
    wanted = {generated[index:index + seed] for index in range(len(generated) - seed + 1)}
    source_positions: dict[str, list[int]] = {}
    for source_start in range(len(source) - seed + 1):
        fragment = source[source_start:source_start + seed]
        if fragment not in wanted:
            continue
        bucket = source_positions.setdefault(fragment, [])
        if len(bucket) < 32:
            bucket.append(source_start)
    best_length = 0
    best_text = ""
    for gen_start in range(0, len(generated) - seed + 1):
        fragment = generated[gen_start:gen_start + seed]
        for source_start in source_positions.get(fragment, []):
            left = 0
            while gen_start - left - 1 >= 0 and source_start - left - 1 >= 0:
                if generated[gen_start - left - 1] != source[source_start - left - 1]:
                    break
                left += 1
            right = seed
            while gen_start + right < len(generated) and source_start + right < len(source):
                if generated[gen_start + right] != source[source_start + right]:
                    break
                right += 1
            length = left + right
            if length > best_length:
                best_length = length
                best_text = generated[gen_start - left:gen_start + right]
    return best_length, best_text


def matching_ngram_positions(
    source: Sequence[T], generated: Sequence[T], size: int, cap: int = 32
) -> dict[tuple[T, ...], list[int]]:
    wanted = {
        tuple(generated[index:index + size])
        for index in range(0, len(generated) - size + 1)
    }
    positions: dict[tuple[T, ...], list[int]] = {}
    for index in range(0, len(source) - size + 1):
        key = tuple(source[index:index + size])
        if key not in wanted:
            continue
        bucket = positions.setdefault(key, [])
        if len(bucket) < cap:
            bucket.append(index)
    return positions


def longest_token_seed_match(source: list[str], generated: list[str], seed: int) -> tuple[int, list[str]]:
    if len(source) < seed or len(generated) < seed:
        return 0, []
    index = matching_ngram_positions(source, generated, seed)
    best_length = 0
    best_tokens: list[str] = []
    for gen_start in range(0, len(generated) - seed + 1):
        key = tuple(generated[gen_start:gen_start + seed])
        for source_start in index.get(key, []):
            left = 0
            while gen_start - left - 1 >= 0 and source_start - left - 1 >= 0:
                if generated[gen_start - left - 1] != source[source_start - left - 1]:
                    break
                left += 1
            right = seed
            while gen_start + right < len(generated) and source_start + right < len(source):
                if generated[gen_start + right] != source[source_start + right]:
                    break
                right += 1
            length = left + right
            if length > best_length:
                best_length = length
                best_tokens = generated[gen_start - left:gen_start + right]
    return best_length, best_tokens


def shingle_ratio(source: Sequence[T], generated: Sequence[T], size: int) -> tuple[float, int, int]:
    total = max(len(generated) - size + 1, 0)
    if total == 0 or len(source) < size:
        return 0.0, 0, total
    source_hashes = {hash(tuple(source[index:index + size])) for index in range(len(source) - size + 1)}
    matched = sum(
        hash(tuple(generated[index:index + size])) in source_hashes
        for index in range(total)
    )
    return matched / total, matched, total


def compare_artifact(
    source_cjk: str,
    source_words: list[str],
    source_significant: str,
    generated_text: str,
    artifact_path: Path,
    args: argparse.Namespace,
) -> dict[str, object]:
    """Compute overlap metrics for one artifact in isolation."""
    generated_cjk = cjk_stream(generated_text)
    generated_words = unicode_word_tokens(generated_text)
    generated_significant = significant_stream(generated_text)

    cjk_seed = max(args.max_cjk_run + 1, 1)
    word_seed = max(args.max_word_run + 1, 1)
    unicode_seed = max(args.max_unicode_run + 1, 1)
    cjk_length, cjk_match = longest_cjk_seed_match(source_cjk, generated_cjk, cjk_seed)
    word_length, word_match = longest_token_seed_match(source_words, generated_words, word_seed)
    unicode_length, unicode_match = longest_cjk_seed_match(
        source_significant, generated_significant, unicode_seed
    )
    cjk_ratio, cjk_matched, cjk_total = shingle_ratio(source_cjk, generated_cjk, 10)
    word_ratio, word_matched, word_total = shingle_ratio(source_words, generated_words, 5)
    unicode_ratio, unicode_matched, unicode_total = shingle_ratio(
        source_significant, generated_significant, 16
    )

    failures: list[str] = []
    if cjk_length > args.max_cjk_run:
        failures.append(f"CJK continuous overlap is {cjk_length}, limit is {args.max_cjk_run}")
    if word_length > args.max_word_run:
        failures.append(
            f"Unicode word overlap is {word_length} words, limit is {args.max_word_run}"
        )
    if unicode_length > args.max_unicode_run:
        failures.append(
            "Normalized alphanumeric overlap is "
            f"{unicode_length}, limit is {args.max_unicode_run}"
        )
    if cjk_total and cjk_ratio >= args.max_shingle_ratio:
        failures.append(
            f"CJK 10-character shingle ratio is {cjk_ratio:.4f}, "
            f"limit is below {args.max_shingle_ratio:.4f}"
        )
    if word_total and word_ratio >= args.max_shingle_ratio:
        failures.append(
            f"Unicode 5-word shingle ratio is {word_ratio:.4f}, "
            f"limit is below {args.max_shingle_ratio:.4f}"
        )
    if unicode_total and unicode_ratio >= args.max_shingle_ratio:
        failures.append(
            f"Normalized 16-character shingle ratio is {unicode_ratio:.4f}, "
            f"limit is below {args.max_shingle_ratio:.4f}"
        )

    return {
        "path": str(artifact_path.resolve()),
        "sha256": sha256_file(artifact_path),
        "passed": not failures,
        "continuous_overlap": {
            "cjk_characters": cjk_length,
            "cjk_preview": cjk_match[:80],
            "unicode_words": word_length,
            "word_preview": " ".join(word_match[:30]),
            "normalized_alphanumeric": unicode_length,
            "normalized_preview": unicode_match[:80],
        },
        "shingles": {
            "cjk_10": {"ratio": cjk_ratio, "matched": cjk_matched, "total": cjk_total},
            "unicode_words_5": {
                "ratio": word_ratio,
                "matched": word_matched,
                "total": word_total,
            },
            "normalized_characters_16": {
                "ratio": unicode_ratio,
                "matched": unicode_matched,
                "total": unicode_total,
            },
        },
        "failures": failures,
    }


def emit_result(result: dict[str, object], json_out: Path | None) -> bool:
    """Print a result and optionally persist the exact same JSON payload."""
    payload = json.dumps(result, ensure_ascii=False, indent=2)
    if json_out:
        try:
            json_out.write_text(payload + "\n", encoding="utf-8")
        except OSError as exc:
            print(f"Cannot write JSON result: {exc}", file=sys.stderr)
            return False
    print(payload)
    return True


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path, help="one source novel TXT or Markdown file")
    parser.add_argument("--generated", required=True, nargs="+", type=Path, help="generated text file(s) or directories")
    parser.add_argument("--max-cjk-run", type=int, default=17, help="largest allowed CJK run; default 17")
    parser.add_argument("--max-word-run", type=int, default=9, help="largest allowed Unicode word run; default 9")
    parser.add_argument("--max-unicode-run", type=int, default=35, help="largest allowed normalized alphanumeric run; default 35")
    parser.add_argument("--max-shingle-ratio", type=float, default=0.01, help="largest allowed match ratio; default 0.01")
    parser.add_argument("--json-out", type=Path, help="optional result path")
    args = parser.parse_args()

    thresholds = {
        "max_cjk_run": args.max_cjk_run,
        "max_word_run": args.max_word_run,
        "max_unicode_run": args.max_unicode_run,
        "max_shingle_ratio": args.max_shingle_ratio,
    }
    if (
        args.max_cjk_run < 0
        or args.max_cjk_run > 17
        or args.max_word_run < 0
        or args.max_word_run > 9
        or args.max_unicode_run < 0
        or args.max_unicode_run > 35
        or args.max_shingle_ratio < 0
        or args.max_shingle_ratio > 0.01
    ):
        result = {
            "passed": False,
            "source": str(args.source),
            "artifacts": [],
            "thresholds": thresholds,
            "errors": [
                "Thresholds may be stricter than the project defaults but never looser "
                "than 17 CJK characters, 9 Unicode words, 35 normalized characters, "
                "or a 0.01 shingle ratio."
            ],
            "notice": NOTICE,
        }
        emit_result(result, args.json_out)
        return 2

    try:
        source_text = read_source_file(args.source)
        generated_paths = expand_generated_paths(args.generated)
        generated_texts = [
            (path, path.read_text(encoding="utf-8"))
            for path in generated_paths
        ]
    except (OSError, UnicodeError, FileNotFoundError, ValueError) as exc:
        result = {
            "passed": False,
            "source": str(args.source),
            "artifacts": [],
            "thresholds": thresholds,
            "errors": [f"Cannot read input: {exc}"],
            "notice": NOTICE,
        }
        emit_result(result, args.json_out)
        return 2

    source_cjk = cjk_stream(source_text)
    source_words = unicode_word_tokens(source_text)
    source_significant = significant_stream(source_text)

    if not source_significant:
        result = {
            "passed": False,
            "source": str(args.source),
            "artifacts": [],
            "thresholds": thresholds,
            "errors": ["Source contains no comparable text; provide extracted TXT or Markdown."],
            "notice": NOTICE,
        }
        emit_result(result, args.json_out)
        return 2

    empty_artifacts = [str(path) for path, text in generated_texts if not significant_stream(text)]
    if empty_artifacts:
        result = {
            "passed": False,
            "source": str(args.source),
            "artifacts": [],
            "thresholds": thresholds,
            "errors": [
                "Generated artifact contains no comparable text: " + path
                for path in empty_artifacts
            ],
            "notice": NOTICE,
        }
        emit_result(result, args.json_out)
        return 2

    artifacts = [
        compare_artifact(
            source_cjk,
            source_words,
            source_significant,
            generated_text,
            artifact_path,
            args,
        )
        for artifact_path, generated_text in generated_texts
    ]

    result = {
        "passed": all(bool(artifact["passed"]) for artifact in artifacts),
        "quality_gate_only": True,
        "source": str(args.source.resolve()),
        "source_sha256": sha256_file(args.source),
        "artifacts": artifacts,
        "excluded_terms": [],
        "thresholds": thresholds,
        "notice": NOTICE,
    }
    if not emit_result(result, args.json_out):
        return 2
    return 0 if result["passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
