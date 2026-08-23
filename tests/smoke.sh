#!/bin/sh

set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
trap 'rm -r "$test_root"' EXIT HUP INT TERM

workbench="$test_root/workbench"
fixture_dir="$test_root/fixtures"
mkdir -p \
    "$workbench/scripts" \
    "$workbench/templates" \
    "$workbench/knowledge" \
    "$workbench/references" \
    "$fixture_dir"

cp "$repo_root/scripts/novelctl.sh" "$workbench/scripts/novelctl.sh"
cp "$repo_root/templates/"*.template "$workbench/templates/"
cp "$repo_root/knowledge/"*.md "$workbench/knowledge/"
: > "$workbench/AGENTS.md"
: > "$workbench/SKILL.md"
: > "$workbench/references/10-workspace-orchestration.md"
: > "$workbench/references/11-long-form-memory-system.md"

source_file="$fixture_dir/长篇 样本.txt"
printf '%s\n' '第一章' '潮水退去以后，钟楼露出了门。' > "$source_file"

NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" register-source "$source_file" > "$test_root/register-1.out"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" register-source "$source_file" > "$test_root/register-2.out"

test -f "$workbench/.novel/ACTIVE_SOURCE.md"
test -f "$workbench/.novel/WORKSPACE.md"
grep -F "$source_file" "$workbench/.novel/ACTIVE_SOURCE.md" >/dev/null
distillation_count=$(find "$workbench/distillations" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d '[:space:]')
test "$distillation_count" -eq 1
if find "$workbench/distillations" -type f -name '*.txt' -print -quit | grep -q .; then
    printf '%s\n' 'source text was copied into the workbench' >&2
    exit 1
fi

distillation_dir=$(sed -n 's/^DISTILLATION_DIR=//p' "$test_root/register-2.out")
pack="$distillation_dir/runtime-style-pack"
{
    printf '%s\n' '# Runtime Style Pack Manifest'
    printf '%s\n' '- Pack ID: `synthetic-pack`'
    printf '%s\n' '- Version: `1.0.0`'
    printf '%s\n' '- Status: `EXPERIMENTAL`'
} > "$pack/PACK_MANIFEST.md"
: > "$pack/WRITING_STYLE_CONTRACT.md"
if NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" activate-pack "$pack" >/dev/null 2>&1; then
    printf '%s\n' 'an unvalidated runtime pack was incorrectly activated' >&2
    exit 1
fi
{
    printf '%s\n' '# Runtime Style Pack Manifest'
    printf '%s\n' '- Pack ID: `synthetic-pack`'
    printf '%s\n' '- Version: `1.0.0`'
    printf '%s\n' '- Status: `VALIDATED`'
} > "$pack/PACK_MANIFEST.md"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" activate-pack "$pack" > "$test_root/activate-pack.out"
grep -F 'PACK_ID=synthetic-pack' "$test_root/activate-pack.out" >/dev/null
test -f "$workbench/.novel/ACTIVE_PACK.md"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" register-source "$source_file" > "$test_root/register-3.out"
test -f "$workbench/.novel/ACTIVE_PACK.md"

project="$workbench/novel-projects/tide-clock"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" scaffold-project tide-clock "$pack" > "$test_root/scaffold.out"
grep -F 'PROJECT_SLUG=tide-clock' "$test_root/scaffold.out" >/dev/null
test -f "$project/craft/INDEX.md"
test -f "$project/state/KNOWLEDGE_LEDGER.md"
if NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" scaffold-project tide-clock "$pack" >/dev/null 2>&1; then
    printf '%s\n' 'an existing project was incorrectly overwritten' >&2
    exit 1
fi
if NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" activate-project "$project" >/dev/null 2>&1; then
    printf '%s\n' 'unresolved project scaffold was incorrectly activated' >&2
    exit 1
fi

printf '%s\n' '# Tide Clock' '' '- Project ID: `tide-clock`' > "$project/NOVEL_PROJECT.md"
for relative_path in \
    AGENTS.md \
    bible/STORY_BIBLE.md \
    outline/MASTER_OUTLINE.md \
    state/MEMORY_INDEX.md \
    state/CURRENT_STATE.md \
    state/RELATIONSHIP_LEDGER.md \
    state/PLOT_THREADS.md \
    state/TIMELINE.md \
    state/KNOWLEDGE_LEDGER.md \
    state/CONTINUITY_LEDGER.md \
    state/DECISION_LOG.md
do
    : > "$project/$relative_path"
done
printf '%s\n' '---' 'name: tide-clock-writer' 'description: Write chapters for the Tide Clock test project.' '---' > "$project/.agents/skills/tide-clock-writer/SKILL.md"

NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" activate-project "$project" > "$test_root/activate.out"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" doctor > "$test_root/doctor.out"

grep -F 'PROJECT_ID=tide-clock' "$test_root/activate.out" >/dev/null
grep -F 'DOCTOR=PASS' "$test_root/doctor.out" >/dev/null

second_source="$fixture_dir/another-novel.md"
printf '%s\n' '# Another novel' 'A different source.' > "$second_source"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" register-source "$second_source" > "$test_root/register-other.out"
test ! -f "$workbench/.novel/ACTIVE_PACK.md"

printf '%s\n' 'smoke test: PASS'
