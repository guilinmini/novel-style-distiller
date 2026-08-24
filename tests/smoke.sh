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
    "$workbench/schemas" \
    "$fixture_dir"

cp "$repo_root/scripts/novelctl.sh" "$workbench/scripts/novelctl.sh"
cp "$repo_root/scripts/style_metrics.py" "$workbench/scripts/style_metrics.py"
cp "$repo_root/templates/"*.template "$workbench/templates/"
cp "$repo_root/knowledge/"*.md "$workbench/knowledge/"
cp "$repo_root/schemas/"*.json "$workbench/schemas/"
: > "$workbench/AGENTS.md"
: > "$workbench/SKILL.md"
: > "$workbench/references/10-workspace-orchestration.md"
: > "$workbench/references/11-long-form-memory-system.md"
: > "$workbench/references/12-batch-writing.md"
: > "$workbench/references/13-style-affinity-calibration.md"

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

v2_pack="$test_root/v2-pack"
mkdir -p "$v2_pack"
printf '%s\n' '# Runtime Style Pack Manifest' '- Pack ID: `synthetic-v2-pack`' '- Pack schema: `2.0`' '- Version: `2.0.0`' '- Status: `VALIDATED`' > "$v2_pack/PACK_MANIFEST.md"
printf '%s\n' '# Synthetic v2 writing contract' > "$v2_pack/WRITING_STYLE_CONTRACT.md"
if NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" activate-pack "$v2_pack" >/dev/null 2>&1; then
    printf '%s\n' 'a v2 pack without companion contracts was incorrectly activated' >&2
    exit 1
fi
printf '%s\n' '# Synthetic reader experience' > "$v2_pack/READER_EXPERIENCE_CONTRACT.md"
printf '%s\n' '{"schema_version":"1.0","metrics":{}}' > "$v2_pack/STYLE_TARGETS.json"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" activate-pack "$v2_pack" > "$test_root/activate-v2-pack.out"
grep -F 'PACK_ID=synthetic-v2-pack' "$test_root/activate-v2-pack.out" >/dev/null
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" activate-pack "$pack" >/dev/null
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" register-source "$source_file" > "$test_root/register-3.out"
test -f "$workbench/.novel/ACTIVE_PACK.md"

project="$workbench/novel-projects/tide-clock"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" scaffold-project tide-clock "$pack" > "$test_root/scaffold.out"
grep -F 'PROJECT_SLUG=tide-clock' "$test_root/scaffold.out" >/dev/null
test -f "$project/craft/INDEX.md"
test -f "$project/craft/web-fiction-opening.md"
test -f "$project/craft/gratification-and-escalation.md"
test -f "$project/state/KNOWLEDGE_LEDGER.md"
test -f "$project/state/REWARD_LEDGER.md"
test -f "$project/state/SERIAL_RHYTHM.md"
test -f "$project/state/BATCH_INDEX.md"
test -f "$project/schemas/chapter-changes.schema.json"
if NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" scaffold-project tide-clock "$pack" >/dev/null 2>&1; then
    printf '%s\n' 'an existing project was incorrectly overwritten' >&2
    exit 1
fi
if NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" activate-project "$project" >/dev/null 2>&1; then
    printf '%s\n' 'unresolved project scaffold was incorrectly activated' >&2
    exit 1
fi

printf '%s\n' '# Tide Clock' '' '- Project ID: `tide-clock`' '- Accepted through: `none`' '- Next planned chapter: `ch-001`' > "$project/NOVEL_PROJECT.md"
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
    state/DECISION_LOG.md \
    state/REWARD_LEDGER.md \
    state/SERIAL_RHYTHM.md
do
    : > "$project/$relative_path"
done
printf '%s\n' '# Current State' '- Accepted through: `none`' '- Next planned chapter: `ch-001`' > "$project/state/CURRENT_STATE.md"
printf '%s\n' '# Memory Index' '- Accepted through: `none`' > "$project/state/MEMORY_INDEX.md"
printf '%s\n' '---' 'name: tide-clock-writer' 'description: Write chapters for the Tide Clock test project.' '---' > "$project/.agents/skills/tide-clock-writer/SKILL.md"

NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" activate-project "$project" > "$test_root/activate.out"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" doctor > "$test_root/doctor.out"

grep -F 'PROJECT_ID=tide-clock' "$test_root/activate.out" >/dev/null
grep -F 'DOCTOR=PASS' "$test_root/doctor.out" >/dev/null

NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-create "$project" 3 2 auto > "$test_root/batch-create.out"
batch_id=$(sed -n 's/^BATCH_ID=//p' "$test_root/batch-create.out")
batch_path=$(sed -n 's/^BATCH_PATH=//p' "$test_root/batch-create.out")
test -n "$batch_id"
test -f "$batch_path/BATCH_JOB.md"
test -f "$batch_path/BATCH_PLAN.md"
if NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-resume "$project" "$batch_id" >/dev/null 2>&1; then
    printf '%s\n' 'an unresolved batch plan was incorrectly resumed' >&2
    exit 1
fi
printf '%s\n' '# Synthetic batch plan' '- Scope: ch-001 through ch-003' '- Mode: AUTO_COMMIT' > "$batch_path/BATCH_PLAN.md"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-resume "$project" "$batch_id" > "$test_root/batch-resume.out"
grep -F 'RESUME_FROM=ch-001' "$test_root/batch-resume.out" >/dev/null

write_accepted_fixture() {
    fixture_chapter=$1
    fixture_next=$2
    printf '%s\n' '# Tide Clock' '' '- Project ID: `tide-clock`' "- Accepted through: \`$fixture_chapter\`" "- Next planned chapter: \`$fixture_next\`" > "$project/NOVEL_PROJECT.md"
    printf '%s\n' '# Current State' "- Accepted through: \`$fixture_chapter\`" "- Next planned chapter: \`$fixture_next\`" > "$project/state/CURRENT_STATE.md"
    printf '%s\n' '# Memory Index' "- Accepted through: \`$fixture_chapter\`" > "$project/state/MEMORY_INDEX.md"
    printf '%s\n' "# $fixture_chapter" 'Synthetic accepted prose.' > "$project/chapters/$fixture_chapter.md"
    printf '%s\n' "# $fixture_chapter Record" '- Status: `ACCEPTED`' > "$project/state/chapter-records/$fixture_chapter.md"
    printf '%s\n' '{' '  "schema_version": "1.0",' '  "project_id": "tide-clock",' "  \"chapter_id\": \"$fixture_chapter\"," '  "status": "ACCEPTED"' '}' > "$project/state/chapter-records/$fixture_chapter.changes.json"
}

write_accepted_fixture ch-001 ch-002
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-checkpoint "$project" "$batch_id" ch-001 ch-002 > "$test_root/checkpoint-1.out"
grep -F 'COMPLETED=1' "$test_root/checkpoint-1.out" >/dev/null
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-pause "$project" "$batch_id" 'synthetic interruption' > "$test_root/batch-pause.out"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-resume "$project" "$batch_id" > "$test_root/batch-resume-2.out"
grep -F 'RESUME_FROM=ch-002' "$test_root/batch-resume-2.out" >/dev/null

write_accepted_fixture ch-002 ch-003
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-checkpoint "$project" "$batch_id" ch-002 ch-003 > "$test_root/checkpoint-2.out"
grep -F 'CHECKPOINT_DUE=yes' "$test_root/checkpoint-2.out" >/dev/null

write_accepted_fixture ch-003 ch-004
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-checkpoint "$project" "$batch_id" ch-003 none > "$test_root/checkpoint-3.out"
grep -F 'STATUS=COMPLETE' "$test_root/checkpoint-3.out" >/dev/null
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-status "$project" "$batch_id" > "$test_root/batch-status.out"
grep -F -- '- Status: `COMPLETE`' "$test_root/batch-status.out" >/dev/null
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-checkpoint "$project" "$batch_id" ch-003 none > "$test_root/checkpoint-repeat.out"
grep -F 'CHECKPOINT=ALREADY_RECORDED' "$test_root/checkpoint-repeat.out" >/dev/null

NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-create "$project" 2 1 review > "$test_root/review-create.out"
review_batch_id=$(sed -n 's/^BATCH_ID=//p' "$test_root/review-create.out")
review_batch_path=$(sed -n 's/^BATCH_PATH=//p' "$test_root/review-create.out")
printf '%s\n' '# Synthetic review batch' '- Scope: ch-004 through ch-005' '- Mode: REVIEW_CHECKPOINTS' > "$review_batch_path/BATCH_PLAN.md"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-resume "$project" "$review_batch_id" >/dev/null
write_accepted_fixture ch-004 ch-005
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-checkpoint "$project" "$review_batch_id" ch-004 ch-005 > "$test_root/review-checkpoint.out"
grep -F 'STATUS=PAUSED_REVIEW' "$test_root/review-checkpoint.out" >/dev/null
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-resume "$project" "$review_batch_id" > "$test_root/review-resume.out"
grep -F 'RESUME_FROM=ch-005' "$test_root/review-resume.out" >/dev/null
write_accepted_fixture ch-005 ch-006
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-checkpoint "$project" "$review_batch_id" ch-005 none > "$test_root/review-complete.out"
grep -F 'STATUS=COMPLETE' "$test_root/review-complete.out" >/dev/null

printf '%s\n' '{"schema_version":"1.0","metrics":{}}' > "$project/style/STYLE_TARGETS.json"
printf '%s\n' '# Style Calibration' '- Bulk writing unlocked: `no`' '- Explicit waiver: `none`' > "$project/state/STYLE_CALIBRATION.md"
if NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-create "$project" 2 1 auto >/dev/null 2>&1; then
    printf '%s\n' 'an uncalibrated multi-chapter batch was incorrectly created' >&2
    exit 1
fi
printf '%s\n' '# Style Calibration' '- Bulk writing unlocked: `yes`' '- Explicit waiver: `none`' > "$project/state/STYLE_CALIBRATION.md"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-create "$project" 2 1 auto > "$test_root/calibrated-create.out"
grep -F 'CHAPTER_COUNT=2' "$test_root/calibrated-create.out" >/dev/null

second_source="$fixture_dir/another-novel.md"
printf '%s\n' '# Another novel' 'A different source.' > "$second_source"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" register-source "$second_source" > "$test_root/register-other.out"
test ! -f "$workbench/.novel/ACTIVE_PACK.md"

printf '%s\n' 'smoke test: PASS'
