#!/usr/bin/env python3
"""Validate a complete novel-style-distiller output pack."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any

try:
    from jsonschema import Draft202012Validator
except ImportError:  # pragma: no cover - exercised only in missing-dependency environments
    Draft202012Validator = None  # type: ignore[assignment]


REQUIRED_ROOT_FILES = [
    "SOURCE_MANIFEST.json",
    "PIPELINE_STATE.json",
    "CHUNK_MANIFEST.json",
    "NOVEL_OVERVIEW.md",
    "PLOT_MAP.md",
    "CHARACTER_ARCS.md",
    "STYLE_PROFILE.md",
    "VOICE_PROFILE.md",
    "verified.jsonl",
    "rejected.jsonl",
    "INDEX.md",
    "CRAFT_REPORT.md",
    "COPYRIGHT_REPORT.md",
    "RELEASE_DECISION.json",
]
REQUIRED_CANDIDATE_FILES = [
    "plot-architecture.jsonl",
    "character-arcs.jsonl",
    "narration-information.jsonl",
    "scene-pacing.jsonl",
    "prose-style.jsonl",
    "voice-tone-dialogue.jsonl",
]
SOURCE_SUFFIXES = {".epub", ".mobi", ".azw", ".azw3", ".pdf"}
SKILL_NAME = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
EXTRACTORS = (
    "plot-architecture",
    "character-arcs",
    "narration-information",
    "scene-pacing",
    "prose-style",
    "voice-tone-dialogue",
)
HOLDOUT_EXTRACTORS = {"prose-style", "voice-tone-dialogue"}
REPO_ROOT = Path(__file__).resolve().parents[1]
SCHEMA_DIR = REPO_ROOT / "schemas"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def resolve_manifest_path(value: object, pack_root: Path) -> Path | None:
    if not isinstance(value, str) or not value:
        return None
    path = Path(value).expanduser()
    if not path.is_absolute():
        path = pack_root / path
    return path.resolve()


def validate_with_schema(
    data: Any, schema_name: str, location: str, errors: list[str]
) -> None:
    if Draft202012Validator is None:
        errors.append("jsonschema is required; run: python3 -m pip install -r requirements.txt")
        return
    schema_path = SCHEMA_DIR / schema_name
    try:
        schema = json.loads(schema_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"cannot load schema {schema_name}: {exc}")
        return
    validator = Draft202012Validator(schema)
    for issue in sorted(validator.iter_errors(data), key=lambda item: list(item.absolute_path)):
        path = ".".join(str(part) for part in issue.absolute_path) or "$"
        errors.append(f"{location} [{path}]: {issue.message}")


def load_json(path: Path, errors: list[str]) -> Any:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as exc:
        errors.append(f"cannot parse {path}: {exc}")
        return {}


def load_jsonl(path: Path, errors: list[str]) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        errors.append(f"cannot read {path}: {exc}")
        return records
    for number, line in enumerate(lines, 1):
        if not line.strip():
            continue
        try:
            value = json.loads(line)
        except json.JSONDecodeError as exc:
            errors.append(f"invalid JSONL {path}:{number}: {exc}")
            continue
        if not isinstance(value, dict):
            errors.append(f"JSONL record must be an object: {path}:{number}")
            continue
        records.append(value)
    return records


def require_object(data: Any, location: str, errors: list[str]) -> dict[str, Any]:
    if isinstance(data, dict):
        return data
    errors.append(f"{location}: root value must be a JSON object")
    return {}


def string_items(value: Any) -> list[str]:
    if not isinstance(value, list):
        return []
    return [item for item in value if isinstance(item, str)]


def parse_skill_frontmatter(path: Path, errors: list[str]) -> dict[str, str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "---":
        errors.append(f"{path}: missing frontmatter")
        return {}
    try:
        end = lines.index("---", 1)
    except ValueError:
        errors.append(f"{path}: unclosed frontmatter")
        return {}
    data: dict[str, str] = {}
    for raw in lines[1:end]:
        match = re.match(r"^([A-Za-z0-9_-]+):\s*(.*)$", raw)
        if match:
            data[match.group(1)] = match.group(2).strip().strip('"\'')
        elif raw.strip():
            errors.append(f"{path}: unsupported multiline or malformed frontmatter")
    return data


def validate_candidate(record: dict[str, Any], location: str, errors: list[str]) -> None:
    validate_with_schema(record, "candidate.schema.json", location, errors)


def is_within(path: Path, root: Path) -> bool:
    try:
        path.resolve().relative_to(root.resolve())
    except ValueError:
        return False
    return True


def safe_pack_file(value: object, root: Path, location: str, errors: list[str]) -> Path | None:
    if not isinstance(value, str) or not value:
        errors.append(f"{location}: non-empty relative path required")
        return None
    raw = Path(value)
    if raw.is_absolute():
        errors.append(f"{location}: path must be relative to the pack")
        return None
    resolved = (root / raw).resolve()
    if not is_within(resolved, root):
        errors.append(f"{location}: path escapes the pack")
        return None
    if not resolved.is_file():
        errors.append(f"{location}: file does not exist: {value}")
        return None
    return resolved


def validate_tests(data: dict[str, Any], location: str, errors: list[str]) -> None:
    cases = data.get("cases")
    if not isinstance(cases, list) or len(cases) < 12:
        errors.append(f"{location}: at least 12 test cases are required")
        return
    counts = Counter(case.get("type") for case in cases if isinstance(case, dict))
    case_ids = [case.get("id") for case in cases if isinstance(case, dict)]
    if None in case_ids or len(case_ids) != len(set(case_ids)):
        errors.append(f"{location}: test case IDs must be present and unique")
    if counts["should_trigger"] < 6:
        errors.append(f"{location}: requires at least 6 should_trigger cases")
    if counts["should_not_trigger"] < 2:
        errors.append(f"{location}: requires at least 2 should_not_trigger cases")
    if counts["sibling_confusion"] < 3:
        errors.append(f"{location}: requires at least 3 sibling_confusion cases")
    kind = data.get("kind")
    if kind == "transferable-technique":
        if counts["transfer"] < 1 or counts["originality"] < 1:
            errors.append(f"{location}: transferable technique requires transfer and originality cases")
        if counts["source_fidelity"] or counts["scope_boundary"]:
            errors.append(f"{location}: transferable technique must not use source-profile-only case types")
    elif kind == "source-profile":
        if counts["source_fidelity"] < 1 or counts["scope_boundary"] < 1:
            errors.append(f"{location}: source profile requires source_fidelity and scope_boundary cases")
        if counts["transfer"] or counts["originality"]:
            errors.append(f"{location}: source profile must route generation through sibling decoys, not execute it")
    else:
        errors.append(f"{location}: invalid skill kind {kind!r}")
    acceptance = data.get("acceptance", {})
    if acceptance.get("generation_runs", 0) < 3:
        errors.append(f"{location}: generation_runs must be at least 3")
    if acceptance.get("maximum_hard_failures") != 0:
        errors.append(f"{location}: maximum_hard_failures must be 0")
    if acceptance.get("all_decoys_must_pass") is not True:
        errors.append(f"{location}: all decoys must pass")
    if acceptance.get("minimum_route_precision", 0) < 0.95:
        errors.append(f"{location}: minimum_route_precision must be at least 0.95")
    if acceptance.get("minimum_route_recall", 0) < 0.90:
        errors.append(f"{location}: minimum_route_recall must be at least 0.90")
    if acceptance.get("minimum_top1_accuracy", 0) < 0.92:
        errors.append(f"{location}: minimum_top1_accuracy must be at least 0.92")
    if kind == "transferable-technique":
        if acceptance.get("minimum_transfer_success", 0) < 0.85:
            errors.append(f"{location}: minimum_transfer_success must be at least 0.85")
        if acceptance.get("all_originality_cases_must_pass") is not True:
            errors.append(f"{location}: all originality cases must pass")
    if kind == "source-profile":
        if acceptance.get("all_source_fidelity_cases_must_pass") is not True:
            errors.append(f"{location}: all source fidelity cases must pass")
        if acceptance.get("all_scope_boundary_cases_must_pass") is not True:
            errors.append(f"{location}: all scope boundary cases must pass")


def validate_test_results(
    data: dict[str, Any], tests: dict[str, Any], location: str, errors: list[str]
) -> None:
    if data.get("skill") != tests.get("skill") or data.get("kind") != tests.get("kind"):
        errors.append(f"{location}: result identity/kind does not match test prompts")
    if data.get("method") not in {"independent-blind-agent", "main-agent-fallback"}:
        errors.append(f"{location}: invalid evaluation method")
    minimum_runs = tests.get("acceptance", {}).get("generation_runs", 3)
    if data.get("minimum_runs_per_case", 0) < minimum_runs:
        errors.append(f"{location}: insufficient runs per case")
    expected_ids = {case.get("id") for case in tests.get("cases", []) if isinstance(case, dict)}
    result_records = data.get("case_results", [])
    result_id_list = [record.get("case_id") for record in result_records if isinstance(record, dict)]
    result_ids = set(result_id_list)
    if expected_ids != result_ids or len(result_id_list) != len(result_ids):
        errors.append(f"{location}: case result IDs do not exactly match test prompt IDs")
    for record in result_records:
        if not isinstance(record, dict):
            errors.append(f"{location}: malformed case result")
            continue
        if record.get("runs", 0) < minimum_runs:
            errors.append(f"{location}: case {record.get('case_id')} has insufficient runs")
        if record.get("passed") is not True or record.get("hard_failures"):
            errors.append(f"{location}: case {record.get('case_id')} did not pass cleanly")
    if data.get("hard_failures"):
        errors.append(f"{location}: aggregate hard failures are present")
    if data.get("passed") is not True:
        errors.append(f"{location}: aggregate passed must be true")
    metrics = data.get("metrics", {})
    acceptance = tests.get("acceptance", {})
    for result_key, threshold_key in (
        ("route_precision", "minimum_route_precision"),
        ("route_recall", "minimum_route_recall"),
        ("top1_accuracy", "minimum_top1_accuracy"),
    ):
        value = metrics.get(result_key)
        threshold = acceptance.get(threshold_key)
        if (
            not isinstance(value, (int, float)) or isinstance(value, bool)
            or not isinstance(threshold, (int, float)) or isinstance(threshold, bool)
            or value < threshold
        ):
            errors.append(f"{location}: {result_key} does not meet configured threshold")
    gates = data.get("gates", {})
    if gates.get("all_decoys_passed") is not True:
        errors.append(f"{location}: not all decoys passed")
    if gates.get("all_sibling_confusion_passed") is not True:
        errors.append(f"{location}: not all sibling confusion cases passed")
    kind = tests.get("kind")
    if kind == "transferable-technique":
        transfer = metrics.get("transfer_success")
        threshold = acceptance.get("minimum_transfer_success")
        if (
            not isinstance(transfer, (int, float)) or isinstance(transfer, bool)
            or not isinstance(threshold, (int, float)) or isinstance(threshold, bool)
            or transfer < threshold
        ):
            errors.append(f"{location}: transfer success does not meet threshold")
        if gates.get("all_originality_cases_passed") is not True:
            errors.append(f"{location}: originality gate failed")
    if kind == "source-profile":
        if metrics.get("source_fidelity_pass_rate") != 1.0 or isinstance(metrics.get("source_fidelity_pass_rate"), bool):
            errors.append(f"{location}: source fidelity pass rate must be 1.0")
        if metrics.get("scope_boundary_pass_rate") != 1.0 or isinstance(metrics.get("scope_boundary_pass_rate"), bool):
            errors.append(f"{location}: scope boundary pass rate must be 1.0")
        if gates.get("all_source_fidelity_cases_passed") is not True:
            errors.append(f"{location}: source fidelity gate failed")
        if gates.get("all_scope_boundary_cases_passed") is not True:
            errors.append(f"{location}: scope boundary gate failed")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack", type=Path, help="distillation output directory")
    args = parser.parse_args()
    root = args.pack.resolve()
    errors: list[str] = []
    warnings: list[str] = []

    if Draft202012Validator is None:
        print(
            "Pack validation requires jsonschema; run: python3 -m pip install -r requirements.txt",
            file=sys.stderr,
        )
        return 2
    if not root.is_dir():
        print(f"Pack directory does not exist: {root}", file=sys.stderr)
        return 2

    for name in REQUIRED_ROOT_FILES:
        if not (root / name).is_file():
            errors.append(f"missing root artifact: {name}")
    for name in REQUIRED_CANDIDATE_FILES:
        if not (root / "candidates" / name).is_file():
            errors.append(f"missing candidate file: candidates/{name}")
    for name in ("canon.jsonl", "scenes.jsonl", "evidence.jsonl"):
        if not (root / "ledgers" / name).is_file():
            errors.append(f"missing ledger: ledgers/{name}")

    source = require_object(
        load_json(root / "SOURCE_MANIFEST.json", errors), "SOURCE_MANIFEST.json", errors
    ) if (root / "SOURCE_MANIFEST.json").exists() else {}
    state = require_object(
        load_json(root / "PIPELINE_STATE.json", errors), "PIPELINE_STATE.json", errors
    ) if (root / "PIPELINE_STATE.json").exists() else {}
    chunks = require_object(
        load_json(root / "CHUNK_MANIFEST.json", errors), "CHUNK_MANIFEST.json", errors
    ) if (root / "CHUNK_MANIFEST.json").exists() else {}
    release = require_object(
        load_json(root / "RELEASE_DECISION.json", errors), "RELEASE_DECISION.json", errors
    ) if (root / "RELEASE_DECISION.json").exists() else {}
    if source:
        validate_with_schema(source, "source-manifest.schema.json", "SOURCE_MANIFEST.json", errors)
    if state:
        validate_with_schema(state, "pipeline-state.schema.json", "PIPELINE_STATE.json", errors)
    if chunks:
        validate_with_schema(chunks, "chunk-manifest.schema.json", "CHUNK_MANIFEST.json", errors)
    declared_generated_paths: set[Path] = set()
    if release:
        validate_with_schema(release, "release-decision.schema.json", "RELEASE_DECISION.json", errors)

    hashes = {
        value
        for value in (
            source.get("normalized_text_sha256"),
            state.get("source_sha256"),
            chunks.get("source_sha256"),
        )
        if isinstance(value, str) and value
    }
    if len(hashes) > 1:
        errors.append("source SHA-256 differs across manifests")
    book_ids = {
        value for value in (
            source.get("book_id"), state.get("book_id"), chunks.get("book_id"),
            release.get("book_id"),
        ) if isinstance(value, str) and value
    }
    if len(book_ids) > 1:
        errors.append("book_id differs across manifests")
    if source.get("completeness") != "complete":
        errors.append("final pack requires completeness=complete")
    text_quality = source.get("text_quality") if isinstance(source.get("text_quality"), dict) else {}
    rights = source.get("rights") if isinstance(source.get("rights"), dict) else {}
    if text_quality.get("locator_reliability") != "high":
        errors.append("final pack requires high locator reliability")
    if rights.get("user_confirmed_lawful_access") is not True:
        errors.append("lawful local access confirmation is missing")
    normalized_text_path_value = source.get("normalized_text_path")
    normalized_text_hash = source.get("normalized_text_sha256")
    if not normalized_text_path_value or not normalized_text_hash:
        errors.append("normalized TXT/Markdown path and SHA-256 are required")
    elif Path(str(normalized_text_path_value)).suffix.lower() not in {".txt", ".md", ".markdown"}:
        errors.append("normalized text must be TXT or Markdown")
    source_path_value = source.get("source_path")
    source_path = resolve_manifest_path(source_path_value, root)
    normalized_text_path = resolve_manifest_path(normalized_text_path_value, root)
    declared_source_hash = source.get("source_sha256")
    source_hashes: set[str] = set()
    for label, path, declared_hash in (
        ("source novel", source_path, declared_source_hash),
        ("normalized source text", normalized_text_path, normalized_text_hash),
    ):
        if path is None or not path.is_file():
            errors.append(f"{label} path is missing or is not a file")
            continue
        if is_within(path, root):
            errors.append(f"{label} must not be inside the distillation pack")
        try:
            actual_hash = sha256_file(path)
        except OSError as exc:
            errors.append(f"cannot hash {label}: {exc}")
            continue
        source_hashes.add(actual_hash)
        if actual_hash != declared_hash:
            errors.append(f"{label} SHA-256 does not match its manifest value")
    if release.get("normalized_text_sha256") != normalized_text_hash:
        errors.append("RELEASE_DECISION normalized source hash mismatch")
    if state.get("status") != "complete":
        errors.append("PIPELINE_STATE status must be complete")
    if state.get("current_stage") != "delivery":
        errors.append("PIPELINE_STATE current_stage must be delivery")

    chunk_records = chunks.get("chunks", []) if isinstance(chunks.get("chunks"), list) else []
    raw_chunk_ids = [record.get("chunk_id") for record in chunk_records if isinstance(record, dict)]
    chunk_ids_list = [value for value in raw_chunk_ids if isinstance(value, str)]
    if len(chunk_ids_list) != len(raw_chunk_ids) or len(chunk_ids_list) != len(set(chunk_ids_list)):
        errors.append("chunk IDs must be present and unique")
    chunk_by_id = {
        record["chunk_id"]: record for record in chunk_records
        if isinstance(record, dict) and isinstance(record.get("chunk_id"), str)
    }
    required_pairs = 0
    completed_pairs = 0
    non_holdout_chunks = 0
    for chunk_id, chunk in chunk_by_id.items():
        holdout = chunk.get("holdout") is True
        if not holdout:
            non_holdout_chunks += 1
        status_map = chunk.get("extractor_status", {})
        for extractor in EXTRACTORS:
            required = extractor not in HOLDOUT_EXTRACTORS or not holdout
            status = status_map.get(extractor) if isinstance(status_map, dict) else None
            if required:
                required_pairs += 1
                if status == "completed":
                    completed_pairs += 1
                else:
                    errors.append(f"chunk {chunk_id}: required extractor {extractor} is {status!r}, not completed")
            elif status != "withheld":
                errors.append(f"chunk {chunk_id}: holdout extractor {extractor} must be withheld")
        for neighbor_key in ("previous_chunk", "next_chunk"):
            neighbor = chunk.get(neighbor_key)
            if neighbor is not None and neighbor not in chunk_by_id:
                errors.append(f"chunk {chunk_id}: {neighbor_key} references unknown chunk {neighbor}")
    coverage = state.get("coverage", {}) if isinstance(state.get("coverage"), dict) else {}
    derived_coverage = {
        "non_holdout_chunks": non_holdout_chunks,
        "completed_chunk_extractor_pairs": completed_pairs,
        "required_chunk_extractor_pairs": required_pairs,
    }
    for key, derived in derived_coverage.items():
        if coverage.get(key) != derived:
            errors.append(f"coverage.{key} is {coverage.get(key)!r}; derived value is {derived}")
    if completed_pairs != required_pairs:
        errors.append("chunk × extractor coverage is incomplete")
    if coverage.get("failed_pairs"):
        errors.append("chunk × extractor coverage contains failed pairs")

    evidence_records = load_jsonl(root / "ledgers/evidence.jsonl", errors) if (root / "ledgers/evidence.jsonl").exists() else []
    for index, record in enumerate(evidence_records, 1):
        validate_with_schema(record, "evidence.schema.json", f"ledgers/evidence.jsonl:{index}", errors)
    raw_evidence_ids = [record.get("id") for record in evidence_records]
    evidence_id_list = [value for value in raw_evidence_ids if isinstance(value, str)]
    if len(evidence_id_list) != len(raw_evidence_ids) or len(evidence_id_list) != len(set(evidence_id_list)):
        errors.append("evidence IDs must be present and unique")
    evidence_by_id = {
        record["id"]: record for record in evidence_records
        if isinstance(record.get("id"), str)
    }
    evidence_ids = set(evidence_by_id)
    for evidence_id, record in evidence_by_id.items():
        if not record.get("locator") or not record.get("chunk_id"):
            errors.append(f"evidence {evidence_id} requires locator and chunk_id")
        if record.get("source_sha256") != source.get("normalized_text_sha256"):
            errors.append(f"evidence {evidence_id} source hash mismatch")
        if record.get("book_id") != source.get("book_id"):
            errors.append(f"evidence {evidence_id} book_id mismatch")
        locator = record.get("locator")
        chunk = chunk_by_id.get(record.get("chunk_id"))
        if chunk is None:
            errors.append(f"evidence {evidence_id} references unknown chunk {record.get('chunk_id')}")
            continue
        if record.get("structural_region") != chunk.get("structural_region"):
            errors.append(f"evidence {evidence_id} structural region does not match its chunk")
        if record.get("holdout") is not chunk.get("holdout"):
            errors.append(f"evidence {evidence_id} holdout flag does not match its chunk")
        start = chunk.get("start_locator")
        end = chunk.get("end_locator")
        if isinstance(locator, str) and isinstance(start, str) and isinstance(end, str):
            if locator < start or locator > end:
                errors.append(f"evidence {evidence_id} locator lies outside its chunk bounds")

    canon_records = load_jsonl(root / "ledgers/canon.jsonl", errors) if (root / "ledgers/canon.jsonl").exists() else []
    scene_records = load_jsonl(root / "ledgers/scenes.jsonl", errors) if (root / "ledgers/scenes.jsonl").exists() else []
    if not canon_records:
        errors.append("canon ledger must contain at least one record")
    if not scene_records:
        errors.append("scene ledger must contain at least one record")
    for index, record in enumerate(canon_records, 1):
        validate_with_schema(record, "canon-record.schema.json", f"ledgers/canon.jsonl:{index}", errors)
        if not record.get("source_locators"):
            errors.append(f"ledgers/canon.jsonl:{index}: source_locators must not be empty")
    scene_ids = [record.get("scene_id") for record in scene_records]
    if None in scene_ids or len(scene_ids) != len(set(scene_ids)):
        errors.append("scene IDs must be present and unique")
    for index, record in enumerate(scene_records, 1):
        validate_with_schema(record, "scene-record.schema.json", f"ledgers/scenes.jsonl:{index}", errors)
        for evidence_id in record.get("evidence_ids", []):
            if evidence_id not in evidence_ids:
                errors.append(f"scene {record.get('scene_id')} references unknown evidence: {evidence_id}")

    candidate_records: list[dict[str, Any]] = []
    expected_category = {name: name.removesuffix(".jsonl") for name in REQUIRED_CANDIDATE_FILES}
    for name in REQUIRED_CANDIDATE_FILES:
        path = root / "candidates" / name
        if path.exists():
            records = load_jsonl(path, errors)
            for index, record in enumerate(records, 1):
                validate_candidate(record, f"{path}:{index}", errors)
                if record.get("status") != "candidate":
                    errors.append(f"{path}:{index}: extracted candidate status must be candidate")
                if record.get("category") != expected_category[name]:
                    errors.append(f"{path}:{index}: category does not match candidate filename")
                for evidence_id in (
                    string_items(record.get("evidence_ids"))
                    + string_items(record.get("counterevidence_ids"))
                ):
                    if evidence_id not in evidence_ids:
                        errors.append(f"candidate {record.get('id')} references unknown evidence: {evidence_id}")
            candidate_records.extend(records)
    verified = load_jsonl(root / "verified.jsonl", errors) if (root / "verified.jsonl").exists() else []
    rejected = load_jsonl(root / "rejected.jsonl", errors) if (root / "rejected.jsonl").exists() else []
    for index, record in enumerate(verified, 1):
        validate_candidate(record, f"verified.jsonl:{index}", errors)
        if record.get("status") != "verified":
            errors.append(f"verified.jsonl:{index}: status must be verified")
    for index, record in enumerate(rejected, 1):
        validate_candidate(record, f"rejected.jsonl:{index}", errors)
        if record.get("status") != "rejected":
            errors.append(f"rejected.jsonl:{index}: status must be rejected")
    raw_candidate_ids = [record.get("id") for record in candidate_records]
    candidate_id_list = [value for value in raw_candidate_ids if isinstance(value, str)]
    if len(candidate_id_list) != len(raw_candidate_ids) or len(candidate_id_list) != len(set(candidate_id_list)):
        errors.append("extracted candidate IDs must be present and unique")
    known_candidates = set(candidate_id_list)
    raw_verified_ids = [record.get("id") for record in verified]
    raw_rejected_ids = [record.get("id") for record in rejected]
    verified_ids_list = [value for value in raw_verified_ids if isinstance(value, str)]
    rejected_ids_list = [value for value in raw_rejected_ids if isinstance(value, str)]
    if len(verified_ids_list) != len(raw_verified_ids) or len(verified_ids_list) != len(set(verified_ids_list)):
        errors.append("verified candidate IDs must be present and unique")
    if len(rejected_ids_list) != len(raw_rejected_ids) or len(rejected_ids_list) != len(set(rejected_ids_list)):
        errors.append("rejected candidate IDs must be present and unique")
    verified_ids = set(verified_ids_list)
    rejected_ids = set(rejected_ids_list)
    if verified_ids & rejected_ids:
        errors.append("a candidate cannot be both verified and rejected")
    if verified_ids | rejected_ids != known_candidates:
        errors.append("verified/rejected records must screen every extracted candidate exactly once")
    base_candidates = {
        record["id"]: record for record in candidate_records
        if isinstance(record.get("id"), str)
    }
    for record in verified + rejected:
        record_id = record.get("id")
        if not isinstance(record_id, str) or record_id not in known_candidates:
            errors.append(f"screening record references unknown candidate: {record_id}")
        elif record.get("category") != base_candidates[record_id].get("category"):
            errors.append(f"screening record category changed for candidate: {record_id}")
        for evidence_id in string_items(record.get("evidence_ids")):
            if evidence_id not in evidence_ids:
                errors.append(f"candidate {record.get('id')} references unknown evidence: {evidence_id}")
    if not verified:
        errors.append("verified.jsonl must contain at least one verified candidate")
    state_candidates = state.get("candidates", {}) if isinstance(state.get("candidates"), dict) else {}
    for key, derived in (("extracted", len(candidate_records)), ("verified", len(verified)), ("rejected", len(rejected))):
        if state_candidates.get(key) != derived:
            errors.append(f"PIPELINE_STATE candidates.{key} is {state_candidates.get(key)!r}; derived value is {derived}")
    minimum_evidence = {
        "plot-architecture": 3,
        "character-arcs": 4,
        "narration-information": 3,
        "scene-pacing": 3,
        "prose-style": 4,
        "voice-tone-dialogue": 4,
    }
    verified_by_id = {
        record["id"]: record for record in verified if isinstance(record.get("id"), str)
    }
    for record in verified:
        category = record.get("category")
        record_evidence_ids = list(dict.fromkeys(string_items(record.get("evidence_ids"))))
        required_count = minimum_evidence.get(category, 1)
        if len(record_evidence_ids) < required_count:
            errors.append(
                f"verified candidate {record.get('id')} has {len(record_evidence_ids)} evidence records; "
                f"{category} requires at least {required_count}"
            )
        records = [evidence_by_id[evidence_id] for evidence_id in record_evidence_ids if evidence_id in evidence_by_id]
        if category in {"prose-style", "voice-tone-dialogue"}:
            if not any(item.get("holdout") is True for item in records):
                errors.append(f"verified candidate {record.get('id')} lacks holdout evidence")
            if len({item.get("chunk_id") for item in records}) < 3:
                errors.append(f"verified candidate {record.get('id')} must span at least 3 chunks")
            if len({item.get("structural_region") for item in records}) < 2:
                errors.append(f"verified candidate {record.get('id')} must span at least 2 structural regions")
        if category == "scene-pacing":
            if len({item.get("chunk_id") for item in records}) < 3:
                errors.append(f"verified scene candidate {record.get('id')} must span at least 3 chunks/scenes")
            if len({item.get("structural_region") for item in records}) < 2:
                errors.append(f"verified scene candidate {record.get('id')} must span at least 2 structural regions")

    skills_root = root / "skills"
    skill_dirs = sorted(path for path in skills_root.iterdir() if path.is_dir()) if skills_root.is_dir() else []
    if not skill_dirs:
        errors.append("no distilled skill directories found")
    source_hash = source.get("normalized_text_sha256")
    source_title = str(source.get("title", ""))
    source_author = str(source.get("author", ""))
    linked_verified_ids: set[str] = set()
    actual_skills: dict[str, str] = {}
    for skill_dir in skill_dirs:
        for filename in ("SKILL.md", "metadata.json", "evidence-index.json", "test-prompts.json", "test-results.json", "test-results.md"):
            if not (skill_dir / filename).is_file():
                errors.append(f"{skill_dir.name}: missing {filename}")
        skill_path = skill_dir / "SKILL.md"
        if not skill_path.exists():
            continue
        meta = parse_skill_frontmatter(skill_path, errors)
        if set(meta) != {"name", "description"}:
            errors.append(f"{skill_dir.name}: SKILL frontmatter must contain name and description only")
        if meta.get("name") != skill_dir.name or not SKILL_NAME.fullmatch(skill_dir.name):
            errors.append(f"{skill_dir.name}: folder and skill name mismatch or invalid name")
        metadata = require_object(
            load_json(skill_dir / "metadata.json", errors), f"{skill_dir.name}/metadata.json", errors
        ) if (skill_dir / "metadata.json").exists() else {}
        evidence_index = require_object(
            load_json(skill_dir / "evidence-index.json", errors),
            f"{skill_dir.name}/evidence-index.json", errors,
        ) if (skill_dir / "evidence-index.json").exists() else {}
        tests = require_object(
            load_json(skill_dir / "test-prompts.json", errors),
            f"{skill_dir.name}/test-prompts.json", errors,
        ) if (skill_dir / "test-prompts.json").exists() else {}
        test_results = require_object(
            load_json(skill_dir / "test-results.json", errors),
            f"{skill_dir.name}/test-results.json", errors,
        ) if (skill_dir / "test-results.json").exists() else {}
        if metadata:
            validate_with_schema(metadata, "skill-metadata.schema.json", f"{skill_dir.name}/metadata.json", errors)
        if evidence_index:
            validate_with_schema(evidence_index, "evidence-index.schema.json", f"{skill_dir.name}/evidence-index.json", errors)
        if tests:
            validate_with_schema(tests, "test-prompts.schema.json", f"{skill_dir.name}/test-prompts.json", errors)
        if test_results:
            validate_with_schema(test_results, "test-results.schema.json", f"{skill_dir.name}/test-results.json", errors)
        if metadata.get("name") != skill_dir.name:
            errors.append(f"{skill_dir.name}: metadata name mismatch")
        if metadata.get("kind") not in {"source-profile", "transferable-technique"}:
            errors.append(f"{skill_dir.name}: invalid or missing kind")
        else:
            actual_skills[skill_dir.name] = metadata.get("kind")
        metadata_source = metadata.get("source") if isinstance(metadata.get("source"), dict) else {}
        if metadata_source.get("source_sha256") != source_hash:
            errors.append(f"{skill_dir.name}: source hash mismatch")
        for field in ("book_id", "title", "author", "edition"):
            if metadata_source.get(field) != source.get(field):
                errors.append(f"{skill_dir.name}: source {field} mismatch")
        if evidence_index.get("skill") != skill_dir.name or evidence_index.get("source_sha256") != source_hash:
            errors.append(f"{skill_dir.name}: evidence index identity/source hash mismatch")
        index_values = evidence_index.get("records", [])
        indexed_records = [record for record in index_values if isinstance(record, dict)] if isinstance(index_values, list) else []
        raw_indexed_ids = [record.get("evidence_id") for record in indexed_records]
        indexed_id_list = [value for value in raw_indexed_ids if isinstance(value, str)]
        if len(indexed_id_list) != len(raw_indexed_ids) or len(indexed_id_list) != len(set(indexed_id_list)):
            errors.append(f"{skill_dir.name}: evidence index IDs must be present and unique")
        indexed_ids = set(indexed_id_list)
        if not indexed_ids:
            errors.append(f"{skill_dir.name}: evidence index has no records")
        if metadata.get("test_status") != "passed":
            errors.append(f"{skill_dir.name}: test_status must be passed")
        metadata_evidence_values = metadata.get("evidence_ids")
        metadata_evidence_id_list = string_items(metadata_evidence_values)
        metadata_evidence_ids = set(metadata_evidence_id_list)
        if indexed_ids != metadata_evidence_ids:
            errors.append(f"{skill_dir.name}: evidence index IDs must exactly match metadata evidence_ids")
        candidate_ids = string_items(metadata.get("candidate_ids"))
        linked_evidence_ids: set[str] = set()
        candidate_categories: set[str] = set()
        for candidate_id in candidate_ids:
            candidate = verified_by_id.get(candidate_id)
            if candidate is None:
                errors.append(f"{skill_dir.name}: candidate {candidate_id} is not verified")
                continue
            linked_verified_ids.add(candidate_id)
            candidate_categories.add(str(candidate.get("category")))
            linked_evidence_ids.update(string_items(candidate.get("evidence_ids")))
            linked_evidence_ids.update(string_items(candidate.get("counterevidence_ids")))
        if candidate_categories and (candidate_categories != {metadata.get("category")}):
            errors.append(f"{skill_dir.name}: metadata category does not match linked candidates")
        if linked_evidence_ids and metadata_evidence_ids != linked_evidence_ids:
            errors.append(f"{skill_dir.name}: metadata evidence_ids must exactly cover linked candidate evidence")
        for evidence_id in metadata_evidence_id_list:
            if evidence_id not in evidence_ids:
                errors.append(f"{skill_dir.name}: unknown evidence id {evidence_id}")
            if evidence_id not in indexed_ids:
                errors.append(f"{skill_dir.name}: evidence id {evidence_id} missing from installed evidence index")
        for indexed in indexed_records:
            canonical = evidence_by_id.get(indexed.get("evidence_id"))
            if canonical is None:
                errors.append(f"{skill_dir.name}: evidence index references unknown evidence {indexed.get('evidence_id')}")
                continue
            for index_key, canonical_key in (
                ("locator", "locator"),
                ("chunk_id", "chunk_id"),
                ("structural_region", "structural_region"),
                ("relation", "relation"),
                ("role", "role"),
                ("excerpt_hash", "excerpt_hash"),
                ("holdout", "holdout"),
            ):
                if indexed.get(index_key) != canonical.get(canonical_key):
                    errors.append(f"{skill_dir.name}: evidence index field {index_key} differs for {indexed.get('evidence_id')}")
        holdout_ids = string_items(metadata.get("holdout_evidence_ids"))
        if metadata.get("category") in {"prose-style", "voice-tone-dialogue"}:
            if not holdout_ids:
                errors.append(f"{skill_dir.name}: style/voice skills require holdout evidence")
            for evidence_id in holdout_ids:
                evidence = evidence_by_id.get(evidence_id)
                if not evidence or evidence.get("holdout") is not True:
                    errors.append(f"{skill_dir.name}: invalid holdout evidence id {evidence_id}")
        if tests:
            if tests.get("skill") != skill_dir.name or tests.get("kind") != metadata.get("kind"):
                errors.append(f"{skill_dir.name}: test identity/kind mismatch")
            validate_tests(tests, str(skill_dir / "test-prompts.json"), errors)
            if test_results:
                validate_test_results(test_results, tests, str(skill_dir / "test-results.json"), errors)
        if metadata.get("kind") == "transferable-technique":
            body = skill_path.read_text(encoding="utf-8")
            for forbidden in (source_title, source_author):
                if forbidden and forbidden in body:
                    errors.append(f"{skill_dir.name}: transferable skill leaks source title/author")

    if linked_verified_ids != verified_ids:
        errors.append("every verified candidate must be linked by at least one distilled skill")
    state_skill_records = state.get("skills", []) if isinstance(state.get("skills"), list) else []
    raw_state_skill_names = [
        record.get("name") for record in state_skill_records if isinstance(record, dict)
    ]
    state_skill_names = [value for value in raw_state_skill_names if isinstance(value, str)]
    if len(state_skill_names) != len(raw_state_skill_names) or len(state_skill_names) != len(set(state_skill_names)):
        errors.append("PIPELINE_STATE skill names must be present and unique")
    if set(state_skill_names) != set(actual_skills):
        errors.append("PIPELINE_STATE skills must exactly match distilled skill directories")
    for record in state_skill_records:
        if not isinstance(record, dict):
            continue
        name = record.get("name")
        if record.get("status") != "passed":
            errors.append(f"PIPELINE_STATE skill {name} status must be passed")
        if name in actual_skills and record.get("kind") != actual_skills[name]:
            errors.append(f"PIPELINE_STATE skill {name} kind mismatch")

    if release:
        if release.get("approved") is not True or release.get("blockers"):
            errors.append("RELEASE_DECISION must be approved with no blockers")
        if release.get("copyright_report") != "COPYRIGHT_REPORT.md":
            errors.append("RELEASE_DECISION copyright report path mismatch")
        release_artifacts = release.get("generated_artifacts")
        release_artifacts = release_artifacts if isinstance(release_artifacts, list) else []
        for index, artifact in enumerate(release_artifacts, 1):
            if not isinstance(artifact, dict):
                errors.append(f"RELEASE_DECISION generated_artifacts[{index}] must be an object")
                continue
            generated_path = safe_pack_file(artifact.get("path"), root, f"generated_artifacts[{index}].path", errors)
            if generated_path is not None:
                if generated_path in declared_generated_paths:
                    errors.append(f"generated_artifacts[{index}]: duplicate artifact path")
                declared_generated_paths.add(generated_path)
            overlap_path = safe_pack_file(
                artifact.get("overlap_result_path"), root,
                f"generated_artifacts[{index}].overlap_result_path", errors,
            )
            if artifact.get("passed") is not True:
                errors.append(f"generated_artifacts[{index}] must be passed")
            if overlap_path is None:
                continue
            overlap = require_object(
                load_json(overlap_path, errors),
                f"generated_artifacts[{index}].overlap_result", errors,
            )
            validate_with_schema(
                overlap, "overlap-result.schema.json",
                f"generated_artifacts[{index}].overlap_result", errors,
            )
            if overlap.get("passed") is not True:
                errors.append(f"generated_artifacts[{index}]: overlap result did not pass")
            if overlap.get("source_sha256") != normalized_text_hash:
                errors.append(f"generated_artifacts[{index}]: overlap result source hash mismatch")
            result_artifacts = overlap.get("artifacts", [])
            matched = False
            for result_artifact in result_artifacts if isinstance(result_artifacts, list) else []:
                if not isinstance(result_artifact, dict) or result_artifact.get("passed") is not True:
                    continue
                result_path = Path(str(result_artifact.get("path", ""))).expanduser()
                if not result_path.is_absolute():
                    result_path = root / result_path
                if generated_path is not None and result_path.resolve() == generated_path.resolve():
                    if result_artifact.get("sha256") != sha256_file(generated_path):
                        errors.append(
                            f"generated_artifacts[{index}]: artifact changed after overlap scan"
                        )
                        continue
                    matched = True
                    break
            if generated_path is not None and not matched:
                errors.append(f"generated_artifacts[{index}]: overlap result does not contain this artifact")

    for path in root.rglob("*"):
        if not path.is_file():
            continue
        if path.suffix.lower() in SOURCE_SUFFIXES:
            errors.append(f"pack contains source-like binary: {path.relative_to(root)}")
        if source_hashes:
            try:
                file_hash = sha256_file(path)
            except OSError as exc:
                errors.append(f"cannot hash pack file {path.relative_to(root)}: {exc}")
                continue
            if file_hash in source_hashes:
                errors.append(f"pack contains a byte-for-byte source copy: {path.relative_to(root)}")

    if not rejected:
        warnings.append("rejected.jsonl is empty; confirm that counterexamples were actually screened")

    for warning in warnings:
        print(f"WARNING: {warning}")
    if errors:
        print("Pack validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print(f"Pack validation passed: {len(skill_dirs)} skills, {len(verified)} verified candidates, {len(evidence_ids)} evidence records.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
