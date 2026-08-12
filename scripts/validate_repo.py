#!/usr/bin/env python3
"""Validate the public novel-style-distiller repository without dependencies."""

from __future__ import annotations

import json
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REQUIRED_FILES = (
    ".github/workflows/validate.yml",
    ".gitignore",
    "CONTRIBUTING.md",
    "LICENSE",
    "NOTICE",
    "README.en.md",
    "README.md",
    "SKILL.md",
    "agents/openai.yaml",
    "examples/synthetic-novel/example-prompt.txt",
    "examples/synthetic-novel/novel.txt",
    "extractors/character-arc-extractor.md",
    "extractors/narration-information-extractor.md",
    "extractors/plot-architecture-extractor.md",
    "extractors/prose-style-extractor.md",
    "extractors/scene-pacing-extractor.md",
    "extractors/voice-tone-dialogue-extractor.md",
    "references/01-intake-and-segmentation.md",
    "references/02-whole-novel-model.md",
    "references/03-parallel-extraction.md",
    "references/04-evidence-validation.md",
    "references/05-build-skills.md",
    "references/06-evaluation.md",
    "references/07-delivery-and-copyright.md",
    "requirements.txt",
    "schemas/candidate.schema.json",
    "schemas/canon-record.schema.json",
    "schemas/chunk-manifest.schema.json",
    "schemas/evidence-index.schema.json",
    "schemas/evidence.schema.json",
    "schemas/overlap-result.schema.json",
    "schemas/pipeline-state.schema.json",
    "schemas/release-decision.schema.json",
    "schemas/scene-record.schema.json",
    "schemas/skill-metadata.schema.json",
    "schemas/source-manifest.schema.json",
    "schemas/test-prompts.schema.json",
    "schemas/test-results.schema.json",
    "scripts/check_overlap.py",
    "scripts/validate_pack.py",
    "scripts/validate_repo.py",
    "templates/CHARACTER_ARCS.md.template",
    "templates/CHUNK_MANIFEST.json.template",
    "templates/COPYRIGHT_REPORT.md.template",
    "templates/CRAFT_REPORT.md.template",
    "templates/INDEX.md.template",
    "templates/NOVEL_OVERVIEW.md.template",
    "templates/PIPELINE_STATE.json.template",
    "templates/PLOT_MAP.md.template",
    "templates/RELEASE_DECISION.json.template",
    "templates/SKILL.source-profile.md.template",
    "templates/SKILL.transferable-technique.md.template",
    "templates/SOURCE_MANIFEST.json.template",
    "templates/STYLE_PROFILE.md.template",
    "templates/VOICE_PROFILE.md.template",
    "templates/candidate-record.json.template",
    "templates/canon-record.json.template",
    "templates/evidence-index.json.template",
    "templates/evidence-record.json.template",
    "templates/scene-record.json.template",
    "templates/skill-metadata.json.template",
    "templates/test-prompts.source-profile.json.template",
    "templates/test-prompts.transferable-technique.json.template",
    "templates/test-results.json.template",
    "templates/test-results.md.template",
    "tests/__init__.py",
    "tests/test_scripts.py",
)
REQUIRED_DIRS = (
    ".github/workflows",
    "agents",
    "examples/synthetic-novel",
    "extractors",
    "references",
    "schemas",
    "scripts",
    "templates",
    "tests",
)
SOURCE_SUFFIXES = {".epub", ".mobi", ".azw", ".azw3", ".pdf"}
MARKDOWN_LINK = re.compile(r"\[[^\]]*\]\(([^)]+)\)")


def frontmatter(path: Path) -> tuple[dict[str, str], list[str]]:
    errors: list[str] = []
    lines = path.read_text(encoding="utf-8").splitlines()
    if not lines or lines[0].strip() != "---":
        return {}, [f"{path}: missing opening frontmatter delimiter"]
    try:
        end = lines.index("---", 1)
    except ValueError:
        return {}, [f"{path}: missing closing frontmatter delimiter"]
    data: dict[str, str] = {}
    current_key: str | None = None
    for raw in lines[1:end]:
        if not raw.strip():
            continue
        match = re.match(r"^([A-Za-z0-9_-]+):(?:\s*(.*))?$", raw)
        if match:
            current_key = match.group(1)
            data[current_key] = (match.group(2) or "").strip().strip('"\'')
        elif raw.startswith((" ", "\t")) and current_key:
            data[current_key] = f"{data[current_key]} {raw.strip()}".strip()
        else:
            errors.append(f"{path}: unsupported frontmatter line: {raw!r}")
    return data, errors


def check_markdown_links(path: Path) -> list[str]:
    errors: list[str] = []
    text = path.read_text(encoding="utf-8")
    for target in MARKDOWN_LINK.findall(text):
        target = target.strip().split("#", 1)[0]
        if not target or target.startswith(("http://", "https://", "mailto:")):
            continue
        if "{{" in target or "<" in target:
            continue
        resolved = (path.parent / target).resolve()
        try:
            resolved.relative_to(ROOT.resolve())
        except ValueError:
            errors.append(f"{path}: link escapes repository: {target}")
            continue
        if not resolved.exists():
            errors.append(f"{path}: broken relative link: {target}")
    return errors


def main() -> int:
    errors: list[str] = []

    for relative in REQUIRED_FILES:
        if not (ROOT / relative).is_file():
            errors.append(f"missing required file: {relative}")
    for relative in REQUIRED_DIRS:
        if not (ROOT / relative).is_dir():
            errors.append(f"missing required directory: {relative}")

    skill = ROOT / "SKILL.md"
    if skill.exists():
        meta, meta_errors = frontmatter(skill)
        errors.extend(meta_errors)
        if set(meta) != {"name", "description"}:
            errors.append(f"SKILL.md frontmatter keys must be name and description only; got {sorted(meta)}")
        if meta.get("name") != "novel-style-distiller":
            errors.append("SKILL.md name must be novel-style-distiller")
        if not meta.get("description"):
            errors.append("SKILL.md description is empty")
        if len(meta.get("description", "")) > 1024:
            errors.append("SKILL.md description exceeds 1024 characters")
        if len(skill.read_text(encoding="utf-8").splitlines()) >= 500:
            errors.append("SKILL.md must stay below 500 lines")

    agent_yaml = ROOT / "agents/openai.yaml"
    if agent_yaml.exists():
        agent_text = agent_yaml.read_text(encoding="utf-8")
        if "$novel-style-distiller" not in agent_text:
            errors.append("agents/openai.yaml default_prompt must mention $novel-style-distiller")
        if "display_name:" not in agent_text or "short_description:" not in agent_text:
            errors.append("agents/openai.yaml is missing required interface fields")

    for path in sorted((ROOT / "schemas").glob("*.json")):
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"invalid JSON schema {path.relative_to(ROOT)}: {exc}")

    for path in sorted((ROOT / "templates").glob("*.json.template")):
        try:
            json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            errors.append(f"invalid JSON template {path.relative_to(ROOT)}: {exc}")

    for path in sorted(ROOT.rglob("*.md")):
        if ".git" not in path.parts:
            errors.extend(check_markdown_links(path))

    for path in ROOT.rglob("*"):
        if path.is_file() and ".git" not in path.parts and path.suffix.lower() in SOURCE_SUFFIXES:
            errors.append(f"source-like binary must not be committed: {path.relative_to(ROOT)}")

    functional_paths = [ROOT / "SKILL.md", ROOT / "references", ROOT / "extractors", ROOT / "templates"]
    banned = re.compile(r"RIA-TV|Adler|nuwa-skill|darwin-skill|podcast|播客|长视频", re.IGNORECASE)
    for base in functional_paths:
        paths = [base] if base.is_file() else [p for p in base.rglob("*") if p.is_file()]
        for path in paths:
            if banned.search(path.read_text(encoding="utf-8", errors="ignore")):
                errors.append(f"legacy workflow term found in {path.relative_to(ROOT)}")

    if errors:
        print("Repository validation failed:")
        for error in errors:
            print(f"- {error}")
        return 1

    print("Repository validation passed.")
    print(f"Checked {len(list((ROOT / 'schemas').glob('*.json')))} schemas and "
          f"{len(list((ROOT / 'templates').glob('*.json.template')))} JSON templates.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
