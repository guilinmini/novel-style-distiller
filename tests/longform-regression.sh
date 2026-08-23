#!/bin/sh

set -eu

repo_root=$(CDPATH= cd "$(dirname "$0")/.." && pwd -P)
test_root=$(mktemp -d)
trap 'rm -r "$test_root"' EXIT HUP INT TERM

workbench="$test_root/workbench"
mkdir -p \
    "$workbench/scripts" \
    "$workbench/templates" \
    "$workbench/knowledge" \
    "$workbench/references" \
    "$workbench/schemas"

cp "$repo_root/scripts/novelctl.sh" "$workbench/scripts/novelctl.sh"
cp "$repo_root/templates/"*.template "$workbench/templates/"
cp "$repo_root/knowledge/"*.md "$workbench/knowledge/"
cp "$repo_root/schemas/"*.json "$workbench/schemas/"
: > "$workbench/AGENTS.md"
: > "$workbench/SKILL.md"
: > "$workbench/references/10-workspace-orchestration.md"
: > "$workbench/references/11-long-form-memory-system.md"
: > "$workbench/references/12-batch-writing.md"

pack="$test_root/runtime-style-pack"
mkdir -p "$pack"
printf '%s\n' '# Runtime Style Pack Manifest' '- Pack ID: `regression-pack`' '- Version: `1.0.0`' '- Status: `VALIDATED`' > "$pack/PACK_MANIFEST.md"
printf '%s\n' '# Synthetic style contract' > "$pack/WRITING_STYLE_CONTRACT.md"

NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" bootstrap >/dev/null
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" scaffold-project serial-120 "$pack" >/dev/null
project="$workbench/novel-projects/serial-120"

for relative_path in \
    AGENTS.md \
    bible/STORY_BIBLE.md \
    outline/MASTER_OUTLINE.md \
    state/RELATIONSHIP_LEDGER.md \
    state/PLOT_THREADS.md \
    state/KNOWLEDGE_LEDGER.md \
    state/CONTINUITY_LEDGER.md \
    state/DECISION_LOG.md
do
    : > "$project/$relative_path"
done
printf '%s\n' '# Serial 120' '- Project ID: `serial-120`' '- Accepted through: `none`' '- Next planned chapter: `ch-001`' > "$project/NOVEL_PROJECT.md"
printf '%s\n' '# Memory Index' '- Accepted through: `none`' > "$project/state/MEMORY_INDEX.md"
printf '%s\n' '# Current State' '- Accepted through: `none`' '- Next planned chapter: `ch-001`' > "$project/state/CURRENT_STATE.md"
printf '%s\n' '# Reward Ledger' '- Delivered rewards: `0`' > "$project/state/REWARD_LEDGER.md"
printf '%s\n' '# Serial Rhythm' '- Accepted through: `none`' > "$project/state/SERIAL_RHYTHM.md"
printf '%s\n' '# Timeline' > "$project/state/TIMELINE.md"
printf '%s\n' '---' 'name: serial-120-writer' 'description: Write synthetic chapters for the 120 chapter state regression.' '---' > "$project/.agents/skills/serial-120-writer/SKILL.md"

NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" activate-project "$project" >/dev/null
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-create "$project" 120 20 auto > "$test_root/batch-create.out"
batch_id=$(sed -n 's/^BATCH_ID=//p' "$test_root/batch-create.out")
batch_path=$(sed -n 's/^BATCH_PATH=//p' "$test_root/batch-create.out")
printf '%s\n' '# 120 chapter deterministic regression' '- Scope: ch-001 through ch-120' '- Mode: AUTO_COMMIT' '- Detailed horizon: rolling five chapters' > "$batch_path/BATCH_PLAN.md"
NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-resume "$project" "$batch_id" >/dev/null

chapter_number=1
object_state=unowned
object_evidence=init
knowledge_state=hidden
knowledge_evidence=init
relationship_state=wary
relationship_evidence=init
thread_state=open
thread_evidence=init

while [ "$chapter_number" -le 120 ]; do
    chapter_suffix=$(printf '%03d' "$chapter_number")
    chapter_id="ch-$chapter_suffix"
    next_number=$((chapter_number + 1))
    next_suffix=$(printf '%03d' "$next_number")
    project_next="ch-$next_suffix"
    if [ "$chapter_number" -eq 120 ]; then
        batch_next=none
    else
        batch_next=$project_next
    fi

    change_type=plot
    subject_id="event-$chapter_suffix"
    before_value="chapter-$((chapter_number - 1))"
    after_value="chapter-$chapter_number"
    if [ "$chapter_number" -eq 30 ]; then
        object_state=held-by-hero
        object_evidence=$chapter_id
        change_type=object
        subject_id=object-key
        before_value=unowned
        after_value=held-by-hero
    elif [ "$chapter_number" -eq 60 ]; then
        knowledge_state=known-by-hero
        knowledge_evidence=$chapter_id
        change_type=knowledge
        subject_id=fact-origin
        before_value=hidden
        after_value=known-by-hero
    elif [ "$chapter_number" -eq 90 ]; then
        relationship_state=allied
        relationship_evidence=$chapter_id
        change_type=relationship
        subject_id=rel-hero-rival
        before_value=wary
        after_value=allied
    elif [ "$chapter_number" -eq 120 ]; then
        thread_state=paid
        thread_evidence=$chapter_id
        change_type=thread
        subject_id=thread-main
        before_value=open
        after_value=paid
    fi

    printf '%s\n' '# Serial 120' '- Project ID: `serial-120`' "- Accepted through: \`$chapter_id\`" "- Next planned chapter: \`$project_next\`" > "$project/NOVEL_PROJECT.md"
    printf '%s\n' '# Memory Index' "- Accepted through: \`$chapter_id\`" "- Latest snapshot: \`state/chapter-records/$chapter_id.changes.json\`" > "$project/state/MEMORY_INDEX.md"
    printf '%s\n' '# Current State' "- Accepted through: \`$chapter_id\`" "- Next planned chapter: \`$project_next\`" "- Object state: \`$object_state\`" "- Knowledge state: \`$knowledge_state\`" "- Relationship state: \`$relationship_state\`" "- Main thread: \`$thread_state\`" > "$project/state/CURRENT_STATE.md"
    printf '%s\n' '# Reward Ledger' "- Delivered rewards: \`$chapter_number\`" "- Last reward: \`reward-$chapter_suffix\`" > "$project/state/REWARD_LEDGER.md"
    printf '%s\n' '# Serial Rhythm' "- Accepted through: \`$chapter_id\`" "- Rolling slot: \`$((chapter_number % 12))\`" > "$project/state/SERIAL_RHYTHM.md"
    printf '| `%s` | synthetic event %s |\n' "$chapter_id" "$chapter_number" >> "$project/state/TIMELINE.md"
    printf '%s\n' "# $chapter_id" "Synthetic accepted chapter $chapter_number." > "$project/chapters/$chapter_id.md"
    printf '%s\n' "# $chapter_id Record" '- Status: `ACCEPTED`' "- Structured changes: \`state/chapter-records/$chapter_id.changes.json\`" > "$project/state/chapter-records/$chapter_id.md"

    changes_file="$project/state/chapter-records/$chapter_id.changes.json"
    {
        printf '%s\n' '{'
        printf '%s\n' '  "schema_version": "1.0",'
        printf '%s\n' '  "project_id": "serial-120",'
        printf '%s\n' "  \"chapter_id\": \"$chapter_id\","
        printf '%s\n' '  "status": "ACCEPTED",'
        printf '%s\n' "  \"accepted_at\": \"synthetic-$chapter_suffix\","
        printf '%s\n' "  \"source\": {\"chapter_file\": \"chapters/$chapter_id.md\", \"chapter_record\": \"state/chapter-records/$chapter_id.md\"},"
        printf '%s\n' '  "style": {"pack_id": "regression-pack", "version": "1.0.0", "contract_hash": "synthetic"},'
        printf '%s\n' '  "fact_snapshot": {'
        printf '%s\n' "    \"story_time\": \"day-$chapter_number\","
        printf '%s\n' "    \"locations\": [{\"id\": \"loc-city\", \"state\": \"active\", \"evidence\": \"$chapter_id\"}],"
        printf '%s\n' "    \"pov\": {\"id\": \"char-hero\", \"state\": \"limited-third\", \"evidence\": \"$chapter_id\"},"
        printf '%s\n' "    \"characters\": [{\"id\": \"char-hero\", \"state\": \"active-$chapter_suffix\", \"evidence\": \"$chapter_id\"}],"
        printf '%s\n' "    \"relationships\": [{\"id\": \"rel-hero-rival\", \"state\": \"$relationship_state\", \"evidence\": \"$relationship_evidence\"}],"
        printf '%s\n' "    \"knowledge\": [{\"id\": \"fact-origin\", \"state\": \"$knowledge_state\", \"evidence\": \"$knowledge_evidence\"}],"
        printf '%s\n' "    \"reader_knowledge\": [{\"id\": \"fact-origin\", \"state\": \"hinted\", \"evidence\": \"$chapter_id\"}],"
        printf '%s\n' "    \"objects\": [{\"id\": \"object-key\", \"state\": \"$object_state\", \"evidence\": \"$object_evidence\"}],"
        printf '%s\n' "    \"resources\": [{\"id\": \"resource-credit\", \"state\": \"$chapter_number\", \"evidence\": \"$chapter_id\"}],"
        printf '%s\n' "    \"conditions\": [{\"id\": \"condition-hero\", \"state\": \"stable\", \"evidence\": \"$chapter_id\"}],"
        printf '%s\n' "    \"world_rules\": [{\"id\": \"rule-cost\", \"state\": \"active\", \"evidence\": \"$chapter_id\"}],"
        printf '%s\n' "    \"factions\": [{\"id\": \"faction-guild\", \"state\": \"watching\", \"evidence\": \"$chapter_id\"}],"
        printf '%s\n' "    \"threads\": [{\"id\": \"thread-main\", \"state\": \"$thread_state\", \"evidence\": \"$thread_evidence\"}],"
        printf '%s\n' "    \"deadlines\": [{\"id\": \"deadline-arc\", \"state\": \"chapter-120\", \"evidence\": \"$chapter_id\"}],"
        printf '%s\n' "    \"immediate_pressure\": \"continue-after-$chapter_id\""
        printf '%s\n' '  },'
        printf '%s\n' "  \"changes\": [{\"change_id\": \"change-$chapter_suffix\", \"type\": \"$change_type\", \"subject_id\": \"$subject_id\", \"before\": \"$before_value\", \"after\": \"$after_value\", \"cause\": \"event-$chapter_suffix\", \"evidence\": \"$chapter_id\", \"updates\": [\"state/CURRENT_STATE.md\"]}],"
        printf '%s\n' '  "quality_gates": {"task": true, "continuity": true, "pov_and_knowledge": true, "style": true, "serial_reward": true, "natural_prose": true, "source_isolation": true},'
        printf '%s\n' "  \"handoff\": {\"next_chapter\": \"$project_next\", \"immediate_pressure\": \"continue\", \"open_obligations\": [\"thread-main\"]}"
        printf '%s\n' '}'
    } > "$changes_file"

    NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-checkpoint "$project" "$batch_id" "$chapter_id" "$batch_next" > "$test_root/checkpoint-$chapter_suffix.out"

    if [ "$chapter_number" -eq 40 ] || [ "$chapter_number" -eq 80 ]; then
        NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-pause "$project" "$batch_id" "synthetic restart at $chapter_id" >/dev/null
        NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-resume "$project" "$batch_id" > "$test_root/resume-$chapter_suffix.out"
        grep -F "RESUME_FROM=$project_next" "$test_root/resume-$chapter_suffix.out" >/dev/null
    fi

    chapter_number=$next_number
done

NOVEL_WORKSPACE_ROOT="$workbench" sh "$workbench/scripts/novelctl.sh" batch-status "$project" "$batch_id" > "$test_root/final-status.out"
grep -F -- '- Status: `COMPLETE`' "$test_root/final-status.out" >/dev/null
grep -F -- '- Completed chapters: `120`' "$test_root/final-status.out" >/dev/null
grep -F -- '- Last committed chapter: `ch-120`' "$test_root/final-status.out" >/dev/null
test "$(grep -c '| checkpoint |' "$project/state/BATCH_INDEX.md")" -eq 120
grep -F '"state": "held-by-hero"' "$project/state/chapter-records/ch-120.changes.json" >/dev/null
grep -F '"state": "known-by-hero"' "$project/state/chapter-records/ch-120.changes.json" >/dev/null
grep -F '"state": "allied"' "$project/state/chapter-records/ch-120.changes.json" >/dev/null
grep -F '"state": "paid"' "$project/state/chapter-records/ch-120.changes.json" >/dev/null
test -f "$project/state/chapter-records/ch-001.changes.json"
test -f "$project/state/chapter-records/ch-060.changes.json"
test -f "$project/state/chapter-records/ch-090.changes.json"
grep -F -- '- Accepted through: `ch-120`' "$project/NOVEL_PROJECT.md" >/dev/null

printf '%s\n' 'long-form 120 chapter state regression: PASS'
