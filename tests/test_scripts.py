from __future__ import annotations

import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path
from typing import Any

from jsonschema import Draft202012Validator


ROOT = Path(__file__).resolve().parents[1]
VALIDATE_PACK = ROOT / "scripts/validate_pack.py"
CHECK_OVERLAP = ROOT / "scripts/check_overlap.py"


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")


def read_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text(encoding="utf-8"))


def write_jsonl(path: Path, records: list[dict[str, Any]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    payload = "".join(json.dumps(record, ensure_ascii=False) + "\n" for record in records)
    path.write_text(payload, encoding="utf-8")


def read_jsonl(path: Path) -> list[dict[str, Any]]:
    return [json.loads(line) for line in path.read_text(encoding="utf-8").splitlines() if line.strip()]


def sha256_bytes(payload: bytes) -> str:
    return hashlib.sha256(payload).hexdigest()


def run_command(arguments: list[str]) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, *arguments],
        cwd=ROOT,
        text=True,
        capture_output=True,
        check=False,
    )


def build_valid_pack(temp_root: Path) -> Path:
    """Build the smallest complete pack that satisfies every published schema."""
    pack = temp_root / "fixture-pack"
    pack.mkdir()
    source_path = temp_root / "fixture-novel.txt"
    source_bytes = (
        "Chapter one. A courier sees a sealed observatory.\n"
        "Chapter two. The missing astronomer left a false chart.\n"
        "Chapter three. The courier opens the observatory at dawn.\n"
    ).encode()
    source_path.write_bytes(source_bytes)
    source_hash = sha256_bytes(source_bytes)
    book_id = "fixture-novel"
    created_at = "2026-01-01T00:00:00Z"

    write_json(
        pack / "SOURCE_MANIFEST.json",
        {
            "schema_version": "1.0",
            "book_id": book_id,
            "title": "Fixture Novel",
            "author": "Fixture Author",
            "edition": "Test edition",
            "publication_year": 2026,
            "original_language": "English",
            "text_language": "English",
            "translator": None,
            "source_path": str(source_path),
            "source_sha256": source_hash,
            "source_format": "txt",
            "normalized_text_path": str(source_path),
            "normalized_text_sha256": source_hash,
            "normalized_text_format": "txt",
            "completeness": "complete",
            "missing_ranges": [],
            "text_quality": {
                "status": "clean",
                "known_issues": [],
                "locator_reliability": "high",
            },
            "rights": {
                "user_confirmed_lawful_access": True,
                "redistribution_permission": "no",
                "notes": "Source stays outside the distributable pack.",
            },
            "analysis_scope": "this work and edition only",
            "created_at": created_at,
        },
    )

    extractor_status = {
        "plot-architecture": "completed",
        "character-arcs": "completed",
        "narration-information": "completed",
        "scene-pacing": "completed",
        "prose-style": "completed",
        "voice-tone-dialogue": "completed",
    }
    regions = ("opening", "middle", "ending")
    chunks: list[dict[str, Any]] = []
    for index, region in enumerate(regions, 1):
        chunks.append(
            {
                "chunk_id": f"chunk-{index:03d}",
                "start_locator": f"ch{index:02d}.s01.p001",
                "end_locator": f"ch{index:02d}.s01.p099",
                "structural_region": region,
                "text_modes": ["narration", "action"],
                "sha256": sha256_bytes(f"fixture chunk {index}".encode()),
                "previous_chunk": None if index == 1 else f"chunk-{index - 1:03d}",
                "next_chunk": None if index == 3 else f"chunk-{index + 1:03d}",
                "overlap_locators": [],
                "holdout": False,
                "extractor_status": dict(extractor_status),
            }
        )
    write_json(
        pack / "CHUNK_MANIFEST.json",
        {
            "schema_version": "1.0",
            "book_id": book_id,
            "source_sha256": source_hash,
            "locator_scheme": "chNN.sNN.pNNN",
            "holdout_policy": {
                "target_ratio": 0,
                "stratified_by": ["structural_region"],
                "frozen_before_extraction": True,
            },
            "chunks": chunks,
        },
    )

    skill_name = "delayed-causal-reveal"
    candidate_id = "plot-001"
    write_json(
        pack / "PIPELINE_STATE.json",
        {
            "schema_version": "1.0",
            "book_id": book_id,
            "source_sha256": source_hash,
            "status": "complete",
            "current_stage": "delivery",
            "completed_artifacts": [
                "CHUNK_MANIFEST.json",
                "verified.jsonl",
                f"skills/{skill_name}/SKILL.md",
            ],
            "coverage": {
                "non_holdout_chunks": 3,
                "completed_chunk_extractor_pairs": 18,
                "required_chunk_extractor_pairs": 18,
                "failed_pairs": [],
            },
            "candidates": {"extracted": 1, "verified": 1, "rejected": 0},
            "skills": [
                {"name": skill_name, "kind": "transferable-technique", "status": "passed"}
            ],
            "user_confirmations": [
                {"type": "lawful-access", "confirmed": True, "at": created_at}
            ],
            "next_action": "",
            "updated_at": created_at,
        },
    )

    for filename in (
        "NOVEL_OVERVIEW.md",
        "PLOT_MAP.md",
        "CHARACTER_ARCS.md",
        "STYLE_PROFILE.md",
        "VOICE_PROFILE.md",
        "INDEX.md",
        "CRAFT_REPORT.md",
    ):
        (pack / filename).write_text(f"# {filename.removesuffix('.md')}\n\nFixture analysis.\n", encoding="utf-8")
    (pack / "COPYRIGHT_REPORT.md").write_text(
        "# Copyright report\n\nPASS: no source text is redistributed.\n", encoding="utf-8"
    )

    evidence_ids = [f"ev-fixture-{index:03d}" for index in range(1, 4)]
    evidence_records: list[dict[str, Any]] = []
    for index, (evidence_id, region) in enumerate(zip(evidence_ids, regions), 1):
        evidence_records.append(
            {
                "id": evidence_id,
                "book_id": book_id,
                "source_sha256": source_hash,
                "locator": f"ch{index:02d}.s01.p010",
                "chunk_id": f"chunk-{index:03d}",
                "structural_region": region,
                "text_mode": "narration",
                "relation": "supports",
                "role": "causal-order observation",
                "verification_excerpt": "Short fixture excerpt.",
                "excerpt_hash": sha256_bytes(f"excerpt {index}".encode()),
                "holdout": False,
                "notes": "Schema-valid fixture evidence.",
            }
        )
    write_jsonl(pack / "ledgers/evidence.jsonl", evidence_records)
    write_jsonl(
        pack / "ledgers/canon.jsonl",
        [
            {
                "id": "canon-observatory-sealed",
                "record_type": "fact",
                "severity": "major",
                "statement": "The observatory is sealed at the story opening.",
                "valid_from": "ch01.s01.p001",
                "valid_to": None,
                "subject_ids": ["observatory"],
                "source_locators": ["ch01.s01.p010"],
                "supporting_fact_ids": [],
                "counterevidence_ids": [],
                "notes": "Fixture canon fact.",
            }
        ],
    )
    write_jsonl(
        pack / "ledgers/scenes.jsonl",
        [
            {
                "scene_id": "scene-001",
                "start_locator": "ch01.s01.p001",
                "end_locator": "ch01.s01.p099",
                "narrative_position": 1,
                "story_time": "night",
                "pov": {
                    "person": "third",
                    "focalizer": "courier",
                    "tense": "past",
                    "allowed_interiority": ["courier"],
                },
                "location": "observatory gate",
                "present_character_ids": ["courier"],
                "entry_state": "The courier expects a routine delivery.",
                "scene_goal": "Deliver the sealed chart.",
                "obstacle": "The observatory is locked.",
                "turn": "A light moves behind a shutter.",
                "choice": "The courier waits and watches.",
                "cost": "The courier misses the return coach.",
                "exit_state": "The delivery has become a mystery.",
                "information_changes": ["Someone may be inside."],
                "opened_thread_ids": ["thread-observatory"],
                "advanced_thread_ids": [],
                "closed_thread_ids": [],
                "tension": {"entry": 0.1, "peak": 0.7, "exit": 0.5},
                "tone": "uneasy",
                "evidence_ids": [evidence_ids[0]],
            }
        ],
    )

    candidate: dict[str, Any] = {
        "id": candidate_id,
        "category": "plot-architecture",
        "candidate_kind": "technique",
        "title": "Delayed causal reveal",
        "scope": "Turning scenes with a legible open question",
        "claim": "Present a consequence before revealing its cause.",
        "observable_markers": ["A consequence appears before its causal explanation."],
        "conditions": ["Readers can retain the unresolved question."],
        "effects": ["Controlled curiosity"],
        "mechanism": "A bounded information gap invites causal inference.",
        "execution": ["Show consequence", "Plant clues", "Reveal cause"],
        "intensity_controls": ["Number of intervening scenes"],
        "failure_modes": ["Delay without legible clues"],
        "evidence_ids": evidence_ids,
        "counterevidence_ids": [],
        "attribution": "work-design",
        "status": "candidate",
    }
    candidate_files = (
        "plot-architecture.jsonl",
        "character-arcs.jsonl",
        "narration-information.jsonl",
        "scene-pacing.jsonl",
        "prose-style.jsonl",
        "voice-tone-dialogue.jsonl",
    )
    write_jsonl(pack / "candidates" / candidate_files[0], [candidate])
    for filename in candidate_files[1:]:
        write_jsonl(pack / "candidates" / filename, [])
    verified = dict(candidate)
    verified["status"] = "verified"
    write_jsonl(pack / "verified.jsonl", [verified])
    write_jsonl(pack / "rejected.jsonl", [])

    skill_root = pack / "skills" / skill_name
    skill_root.mkdir(parents=True)
    (skill_root / "SKILL.md").write_text(
        "---\n"
        f"name: {skill_name}\n"
        "description: Use when an original plot needs a delayed causal explanation that preserves reader orientation.\n"
        "---\n\n"
        "# Delayed Causal Reveal\n\n"
        "Use new characters, settings, events, and wording.\n",
        encoding="utf-8",
    )
    write_json(
        skill_root / "metadata.json",
        {
            "schema_version": "1.0",
            "name": skill_name,
            "kind": "transferable-technique",
            "category": "plot-architecture",
            "source": {
                "book_id": book_id,
                "title": "Fixture Novel",
                "author": "Fixture Author",
                "edition": "Test edition",
                "translator": None,
                "source_sha256": source_hash,
            },
            "candidate_ids": [candidate_id],
            "evidence_ids": evidence_ids,
            "holdout_evidence_ids": [],
            "confidence": "high",
            "relations": [],
            "originality_constraints": {
                "forbid_source_characters": True,
                "forbid_source_worldbuilding": True,
                "forbid_plot_beat_mapping": True,
                "overlap_check_required": True,
            },
            "test_status": "passed",
            "created_at": created_at,
        },
    )
    write_json(
        skill_root / "evidence-index.json",
        {
            "schema_version": "1.0",
            "skill": skill_name,
            "source_sha256": source_hash,
            "records": [
                {
                    "evidence_id": record["id"],
                    "locator": record["locator"],
                    "chunk_id": record["chunk_id"],
                    "structural_region": record["structural_region"],
                    "relation": record["relation"],
                    "role": record["role"],
                    "paraphrase": f"Fixture support from {record['structural_region']}.",
                    "excerpt_hash": record["excerpt_hash"],
                    "holdout": record["holdout"],
                }
                for record in evidence_records
            ],
        },
    )

    case_types = (
        ["should_trigger"] * 6
        + ["should_not_trigger"] * 2
        + ["sibling_confusion"] * 3
        + ["edge_case", "transfer", "originality"]
    )
    cases: list[dict[str, Any]] = []
    for index, case_type in enumerate(case_types, 1):
        expected_primary = None if case_type in {"should_not_trigger", "sibling_confusion"} else skill_name
        cases.append(
            {
                "id": f"case-{index:02d}",
                "type": case_type,
                "actor": {"prompt": f"Fixture prompt {index}", "fixture_refs": []},
                "routing_oracle": {
                    "expected_primary": expected_primary,
                    "allowed_secondary": [],
                    "forbidden": [] if expected_primary else [skill_name],
                },
                "expected_effect": "A controlled information gap." if expected_primary else "No activation.",
                "hard_gates": ["original wording"] if case_type == "originality" else [],
            }
        )
    write_json(
        skill_root / "test-prompts.json",
        {
            "schema_version": "1.0",
            "skill": skill_name,
            "kind": "transferable-technique",
            "cases": cases,
            "acceptance": {
                "generation_runs": 3,
                "minimum_route_precision": 0.95,
                "minimum_route_recall": 0.90,
                "minimum_top1_accuracy": 0.92,
                "minimum_transfer_success": 0.85,
                "maximum_hard_failures": 0,
                "all_decoys_must_pass": True,
                "all_originality_cases_must_pass": True,
            },
        },
    )
    write_json(
        skill_root / "test-results.json",
        {
            "schema_version": "1.0",
            "skill": skill_name,
            "kind": "transferable-technique",
            "method": "independent-blind-agent",
            "minimum_runs_per_case": 3,
            "case_results": [
                {
                    "case_id": case["id"],
                    "runs": 3,
                    "passed": True,
                    "median_score": 1.0,
                    "hard_failures": [],
                    "notes": "Fixture evaluation.",
                }
                for case in cases
            ],
            "metrics": {
                "route_precision": 1.0,
                "route_recall": 1.0,
                "top1_accuracy": 1.0,
                "transfer_success": 1.0,
                "source_fidelity_pass_rate": None,
                "scope_boundary_pass_rate": None,
            },
            "gates": {
                "all_decoys_passed": True,
                "all_sibling_confusion_passed": True,
                "all_originality_cases_passed": True,
                "all_source_fidelity_cases_passed": None,
                "all_scope_boundary_cases_passed": None,
            },
            "hard_failures": [],
            "passed": True,
            "evaluated_at": created_at,
        },
    )
    (skill_root / "test-results.md").write_text("# Results\n\nPASS\n", encoding="utf-8")

    write_json(
        pack / "RELEASE_DECISION.json",
        {
            "schema_version": "1.0",
            "book_id": book_id,
            "normalized_text_sha256": source_hash,
            "copyright_report": "COPYRIGHT_REPORT.md",
            "approved": True,
            "blockers": [],
            "generated_artifacts": [],
            "reviewer": "fixture-reviewer",
            "reviewed_at": created_at,
        },
    )
    return pack


def replace_source_hash_references(pack: Path, digest: str) -> None:
    """Keep every cross-artifact hash consistent while a test changes the source claim."""
    manifest = read_json(pack / "SOURCE_MANIFEST.json")
    manifest["source_sha256"] = digest
    manifest["normalized_text_sha256"] = digest
    write_json(pack / "SOURCE_MANIFEST.json", manifest)

    state = read_json(pack / "PIPELINE_STATE.json")
    state["source_sha256"] = digest
    write_json(pack / "PIPELINE_STATE.json", state)
    chunks = read_json(pack / "CHUNK_MANIFEST.json")
    chunks["source_sha256"] = digest
    write_json(pack / "CHUNK_MANIFEST.json", chunks)

    evidence = read_jsonl(pack / "ledgers/evidence.jsonl")
    for record in evidence:
        record["source_sha256"] = digest
    write_jsonl(pack / "ledgers/evidence.jsonl", evidence)

    skill = pack / "skills/delayed-causal-reveal"
    metadata = read_json(skill / "metadata.json")
    metadata["source"]["source_sha256"] = digest
    write_json(skill / "metadata.json", metadata)
    index = read_json(skill / "evidence-index.json")
    index["source_sha256"] = digest
    write_json(skill / "evidence-index.json", index)
    decision = read_json(pack / "RELEASE_DECISION.json")
    decision["normalized_text_sha256"] = digest
    write_json(pack / "RELEASE_DECISION.json", decision)


class RepositoryValidationTests(unittest.TestCase):
    def test_repository_validator(self) -> None:
        result = run_command([str(ROOT / "scripts/validate_repo.py")])
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


class OverlapTests(unittest.TestCase):
    def run_overlap(self, source: str, *generated: str) -> subprocess.CompletedProcess[str]:
        with tempfile.TemporaryDirectory() as temp:
            temp_path = Path(temp)
            source_path = temp_path / "source.txt"
            source_path.write_text(source, encoding="utf-8")
            generated_paths: list[Path] = []
            for index, text in enumerate(generated, 1):
                path = temp_path / f"generated-{index}.txt"
                path.write_text(text, encoding="utf-8")
                generated_paths.append(path)
            return run_command(
                [
                    str(CHECK_OVERLAP),
                    "--source",
                    str(source_path),
                    "--generated",
                    *(str(path) for path in generated_paths),
                ]
            )

    def test_original_text_passes(self) -> None:
        result = self.run_overlap(
            "潮水漫过石阶，守塔人把铜钥匙压在旧地图下面。",
            "沙漠列车停在无名站台，工程师拆开一只结霜的仪表。",
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(json.loads(result.stdout)["passed"])

    def test_cjk_copy_fails(self) -> None:
        copied = "守塔人把铜钥匙压在旧地图下面然后关掉了灯"
        result = self.run_overlap(
            f"潮水漫过石阶，{copied}。港口陷入黑暗。",
            f"风暴来临时，{copied}。",
        )
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        payload = json.loads(result.stdout)
        self.assertFalse(payload["passed"])
        self.assertGreaterEqual(payload["artifacts"][0]["continuous_overlap"]["cjk_characters"], 18)

    def test_cyrillic_copy_fails(self) -> None:
        copied = "Старый смотритель медленно закрыл тяжелую дверь и спрятал ключ под картой"
        result = self.run_overlap(
            f"Ночью начался шторм. {copied}. Затем погас маяк.",
            f"Когда пришел поезд, {copied}.",
        )
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        payload = json.loads(result.stdout)
        overlap = payload["artifacts"][0]["continuous_overlap"]
        self.assertFalse(payload["passed"])
        self.assertTrue(overlap["unicode_words"] >= 10 or overlap["normalized_alphanumeric"] >= 36)

    def test_each_generated_file_is_checked_independently(self) -> None:
        copied = "守塔人把铜钥匙压在旧地图下面然后关掉了灯"
        result = self.run_overlap(
            f"潮水漫过石阶，{copied}。港口陷入黑暗。",
            copied,
            "沙漠中的风向仪转了一整夜。" * 500,
        )
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        payload = json.loads(result.stdout)
        self.assertFalse(payload["passed"])
        self.assertEqual(len(payload["artifacts"]), 2)
        self.assertFalse(payload["artifacts"][0]["passed"])

    def test_empty_or_unsupported_inputs_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            temp_path = Path(temp)
            empty_source = temp_path / "source.txt"
            empty_generated = temp_path / "generated.txt"
            empty_source.write_text("", encoding="utf-8")
            empty_generated.write_text("", encoding="utf-8")
            empty = run_command(
                [str(CHECK_OVERLAP), "--source", str(empty_source), "--generated", str(empty_generated)]
            )
            self.assertNotEqual(empty.returncode, 0, empty.stdout + empty.stderr)
            self.assertFalse(json.loads(empty.stdout)["passed"])

            unsupported = temp_path / "generated.json"
            unsupported.write_text("{}", encoding="utf-8")
            result = run_command(
                [str(CHECK_OVERLAP), "--source", str(empty_source), "--generated", str(unsupported)]
            )
            self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)


class PackValidationTests(unittest.TestCase):
    def validate(self, pack: Path) -> subprocess.CompletedProcess[str]:
        return run_command([str(VALIDATE_PACK), str(pack)])

    def assert_invalid(self, pack: Path) -> subprocess.CompletedProcess[str]:
        result = self.validate(pack)
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        return result

    def test_minimal_schema_valid_complete_pack_passes(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            pack = build_valid_pack(Path(temp))
            skill = pack / "skills/delayed-causal-reveal"
            schema_instances: dict[str, list[dict[str, Any]]] = {
                "source-manifest.schema.json": [read_json(pack / "SOURCE_MANIFEST.json")],
                "pipeline-state.schema.json": [read_json(pack / "PIPELINE_STATE.json")],
                "chunk-manifest.schema.json": [read_json(pack / "CHUNK_MANIFEST.json")],
                "release-decision.schema.json": [read_json(pack / "RELEASE_DECISION.json")],
                "evidence.schema.json": read_jsonl(pack / "ledgers/evidence.jsonl"),
                "canon-record.schema.json": read_jsonl(pack / "ledgers/canon.jsonl"),
                "scene-record.schema.json": read_jsonl(pack / "ledgers/scenes.jsonl"),
                "candidate.schema.json": (
                    read_jsonl(pack / "candidates/plot-architecture.jsonl")
                    + read_jsonl(pack / "verified.jsonl")
                ),
                "skill-metadata.schema.json": [read_json(skill / "metadata.json")],
                "evidence-index.schema.json": [read_json(skill / "evidence-index.json")],
                "test-prompts.schema.json": [read_json(skill / "test-prompts.json")],
                "test-results.schema.json": [read_json(skill / "test-results.json")],
            }
            for schema_name, instances in schema_instances.items():
                schema = read_json(ROOT / "schemas" / schema_name)
                validator = Draft202012Validator(schema)
                for index, instance in enumerate(instances, 1):
                    with self.subTest(schema=schema_name, instance=index):
                        issues = sorted(
                            validator.iter_errors(instance),
                            key=lambda issue: list(issue.absolute_path),
                        )
                        self.assertEqual([], issues, "\n".join(issue.message for issue in issues))
            result = self.validate(pack)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_schema_invalid_artifact_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            pack = build_valid_pack(Path(temp))
            manifest = read_json(pack / "SOURCE_MANIFEST.json")
            manifest["analysis_scope"] = "all works by this author"
            write_json(pack / "SOURCE_MANIFEST.json", manifest)
            self.assert_invalid(pack)

    def test_empty_chunks_cannot_fake_complete_coverage(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            pack = build_valid_pack(Path(temp))
            manifest = read_json(pack / "CHUNK_MANIFEST.json")
            manifest["chunks"] = []
            write_json(pack / "CHUNK_MANIFEST.json", manifest)
            self.assert_invalid(pack)

    def test_self_reported_coverage_must_match_chunks(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            pack = build_valid_pack(Path(temp))
            state = read_json(pack / "PIPELINE_STATE.json")
            state["coverage"]["completed_chunk_extractor_pairs"] = 999
            state["coverage"]["required_chunk_extractor_pairs"] = 999
            write_json(pack / "PIPELINE_STATE.json", state)
            self.assert_invalid(pack)

    def test_empty_verified_candidates_fail(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            pack = build_valid_pack(Path(temp))
            write_jsonl(pack / "verified.jsonl", [])
            self.assert_invalid(pack)

    def test_unapproved_or_blocked_release_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            pack = build_valid_pack(Path(temp))
            decision = read_json(pack / "RELEASE_DECISION.json")
            decision["approved"] = False
            decision["blockers"] = ["Copyright review is incomplete."]
            write_json(pack / "RELEASE_DECISION.json", decision)
            self.assert_invalid(pack)

    def test_source_or_normalized_text_inside_pack_fails(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            pack = build_valid_pack(Path(temp))
            internal = pack / "source.txt"
            internal.write_text("Source text must never ship in a pack.\n", encoding="utf-8")
            digest = sha256_bytes(internal.read_bytes())
            manifest = read_json(pack / "SOURCE_MANIFEST.json")
            manifest["source_path"] = "source.txt"
            manifest["normalized_text_path"] = "source.txt"
            write_json(pack / "SOURCE_MANIFEST.json", manifest)
            replace_source_hash_references(pack, digest)
            self.assert_invalid(pack)

    def test_declared_source_hash_must_match_file(self) -> None:
        with tempfile.TemporaryDirectory() as temp:
            pack = build_valid_pack(Path(temp))
            replace_source_hash_references(pack, "0" * 64)
            self.assert_invalid(pack)


if __name__ == "__main__":
    unittest.main()
