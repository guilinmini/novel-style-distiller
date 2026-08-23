#!/bin/sh

set -eu

script_dir=$(CDPATH= cd "$(dirname "$0")" && pwd -P)
default_root=$(CDPATH= cd "$script_dir/.." && pwd -P)
workbench_root=${NOVEL_WORKSPACE_ROOT:-$default_root}

die() {
    printf '%s\n' "novelctl: $*" >&2
    exit 1
}

now_utc() {
    date -u '+%Y-%m-%dT%H:%M:%SZ'
}

canonical_file() {
    input_path=$1
    case "$input_path" in
        *'
'*) die "paths containing newlines are not supported" ;;
    esac
    case "$input_path" in
        /*) absolute_path=$input_path ;;
        *) absolute_path=$(pwd -P)/$input_path ;;
    esac
    file_dir=$(dirname "$absolute_path")
    file_name=$(basename "$absolute_path")
    canonical_dir=$(CDPATH= cd "$file_dir" 2>/dev/null && pwd -P) || die "directory does not exist: $file_dir"
    printf '%s/%s\n' "$canonical_dir" "$file_name"
}

canonical_dir() {
    input_path=$1
    case "$input_path" in
        *'
'*) die "paths containing newlines are not supported" ;;
    esac
    case "$input_path" in
        /*) absolute_path=$input_path ;;
        *) absolute_path=$(pwd -P)/$input_path ;;
    esac
    (CDPATH= cd "$absolute_path" 2>/dev/null && pwd -P) || die "directory does not exist: $input_path"
}

hash_file() {
    target_file=$1
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$target_file" | awk '{print $1}'
    elif command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$target_file" | awk '{print $1}'
    elif command -v openssl >/dev/null 2>&1; then
        openssl dgst -sha256 "$target_file" | awk '{print $NF}'
    else
        checksum=$(cksum "$target_file" | awk '{print $1}')
        printf 'cksum-%s\n' "$checksum"
    fi
}

slugify() {
    raw_name=$1
    slug=$(printf '%s' "$raw_name" \
        | tr '[:upper:]' '[:lower:]' \
        | sed 's/[^a-z0-9][^a-z0-9]*/-/g; s/^-//; s/-$//')
    printf '%s\n' "$slug"
}

markdown_field() {
    field_file=$1
    field_name=$2
    awk -v prefix="- $field_name: \`" '
        index($0, prefix) == 1 {
            value = substr($0, length(prefix) + 1)
            sub(/`.*/, "", value)
            print value
            exit
        }
    ' "$field_file"
}

plain_list_field() {
    field_file=$1
    field_name=$2
    sed -n "s/^- $field_name: *//p" "$field_file" | sed -n '1p' | tr -d '`'
}

replace_markdown_field() {
    field_file=$1
    field_name=$2
    field_value=$3
    case "$field_value" in
        *'`'*|*'
'*) die "invalid value for $field_name" ;;
    esac
    field_temp=$(mktemp "$(dirname "$field_file")/.field.XXXXXX")
    awk -v prefix="- $field_name: " -v replacement="- $field_name: \`$field_value\`" '
        index($0, prefix) == 1 { print replacement; found = 1; next }
        { print }
        END { if (!found) exit 42 }
    ' "$field_file" > "$field_temp" || {
        rm -f "$field_temp"
        die "missing field in $field_file: $field_name"
    }
    mv "$field_temp" "$field_file"
}

project_id_from_path() {
    project_path=$1
    project_id=$(sed -n 's/^- Project ID: `\([^`]*\)`.*/\1/p' "$project_path/NOVEL_PROJECT.md" | sed -n '1p')
    [ -n "$project_id" ] || die "project has no Project ID: $project_path"
    printf '%s\n' "$project_id"
}

project_next_chapter() {
    project_path=$1
    next_chapter=$(sed -n 's/^- Next planned chapter: *//p' "$project_path/NOVEL_PROJECT.md" | sed -n '1p' | tr -d '`')
    [ -n "$next_chapter" ] || die "project has no Next planned chapter"
    printf '%s\n' "$next_chapter"
}

batch_job_path() {
    project_path=$1
    requested_batch_id=${2:-}
    if [ -n "$requested_batch_id" ]; then
        printf '%s/state/batches/%s/BATCH_JOB.md\n' "$project_path" "$requested_batch_id"
        return
    fi
    active_batch_file="$project_path/state/ACTIVE_BATCH.md"
    [ -f "$active_batch_file" ] || die "project has no active batch"
    active_batch_path=$(sed -n 's/^- Batch path: //p' "$active_batch_file" | sed -n '1p')
    [ -n "$active_batch_path" ] || die "active batch pointer is invalid"
    printf '%s\n' "$active_batch_path"
}

resolve_batch_job() {
    project_path=$1
    requested_batch_id=${2:-}
    case "$requested_batch_id" in
        '') ;;
        batch-*)
            case "$requested_batch_id" in
                *[!a-zA-Z0-9-]*) die "invalid batch ID: $requested_batch_id" ;;
            esac
            ;;
        *) die "invalid batch ID: $requested_batch_id" ;;
    esac
    unresolved_job=$(batch_job_path "$project_path" "$requested_batch_id")
    [ -f "$unresolved_job" ] || die "batch job does not exist: $unresolved_job"
    resolved_job=$(canonical_file "$unresolved_job")
    case "$resolved_job" in
        "$project_path"/state/batches/*/BATCH_JOB.md) ;;
        *) die "batch job escapes project state: $resolved_job" ;;
    esac
    printf '%s\n' "$resolved_job"
}

write_active_batch() {
    project_path=$1
    batch_id=$2
    job_path=$3
    batch_status=$4
    active_temp=$(mktemp "$project_path/state/.active-batch.XXXXXX")
    {
        printf '%s\n\n' '# Active Batch Writing Job'
        printf '%s\n' "- Batch ID: \`$batch_id\`"
        printf '%s\n' "- Status: \`$batch_status\`"
        printf '%s\n' "- Batch path: $job_path"
        printf '%s\n' "- Updated at: \`$(now_utc)\`"
    } > "$active_temp"
    mv "$active_temp" "$project_path/state/ACTIVE_BATCH.md"
}

append_batch_event() {
    project_path=$1
    batch_id=$2
    event_name=$3
    event_status=$4
    event_chapter=$5
    event_note=$6
    case "$event_note" in
        *'|'*|*'
'*) event_note=$(printf '%s' "$event_note" | tr '|\n' '/ ') ;;
    esac
    printf '| %s | `%s` | %s | `%s` | `%s` | %s |\n' \
        "$(now_utc)" "$batch_id" "$event_name" "$event_status" "$event_chapter" "$event_note" \
        >> "$project_path/state/BATCH_INDEX.md"
}

ensure_layout() {
    mkdir -p "$workbench_root/.novel" "$workbench_root/distillations" "$workbench_root/novel-projects"
    workspace_file="$workbench_root/.novel/WORKSPACE.md"
    if [ ! -f "$workspace_file" ]; then
        if [ -f "$workbench_root/templates/WORKSPACE_STATE.md.template" ]; then
            cp "$workbench_root/templates/WORKSPACE_STATE.md.template" "$workspace_file"
        else
            temp_file=$(mktemp "$workbench_root/.novel/.workspace.XXXXXX")
            {
                printf '%s\n\n' '# Novel Workbench State'
                printf '%s\n' '- Schema version: `2.0`'
                printf '%s\n' '- Status: `READY`'
                printf '%s\n' '- Active source pointer: `.novel/ACTIVE_SOURCE.md`'
                printf '%s\n' '- Active project pointer: `.novel/ACTIVE_PROJECT.md`'
                printf '%s\n' '- Active batch pointer: project-local `state/ACTIVE_BATCH.md`'
            } > "$temp_file"
            mv "$temp_file" "$workspace_file"
        fi
    fi
}

register_source() {
    [ "$#" -eq 1 ] || die "usage: novelctl.sh register-source <novel-path>"
    ensure_layout

    source_path=$(canonical_file "$1")
    [ -f "$source_path" ] || die "source is not a regular file: $source_path"
    [ -r "$source_path" ] || die "source is not readable: $source_path"

    source_name=$(basename "$source_path")
    source_stem=${source_name%.*}
    [ "$source_stem" != "$source_name" ] || source_stem=$source_name
    source_format=${source_name##*.}
    [ "$source_format" != "$source_name" ] || source_format=unknown
    source_format=$(printf '%s' "$source_format" | tr '[:upper:]' '[:lower:]')
    source_hash=$(hash_file "$source_path")
    source_size=$(wc -c < "$source_path" | tr -d '[:space:]')
    short_hash=$(printf '%s' "$source_hash" | cut -c1-12)
    source_slug=$(slugify "$source_stem")
    [ -n "$source_slug" ] || source_slug=source-$short_hash

    previous_active_hash=
    if [ -f "$workbench_root/.novel/ACTIVE_SOURCE.md" ]; then
        previous_active_hash=$(sed -n 's/^- Source SHA-256: `\([^`]*\)`.*/\1/p' "$workbench_root/.novel/ACTIVE_SOURCE.md" | sed -n '1p')
    fi

    distillation_dir="$workbench_root/distillations/$source_slug"
    request_file="$distillation_dir/audit/SOURCE_REQUEST.md"
    if [ -f "$request_file" ]; then
        existing_hash=$(sed -n 's/^- Source SHA-256: `\([^`]*\)`.*/\1/p' "$request_file" | sed -n '1p')
        if [ -n "$existing_hash" ] && [ "$existing_hash" != "$source_hash" ]; then
            source_slug=$source_slug-$short_hash
            distillation_dir="$workbench_root/distillations/$source_slug"
            request_file="$distillation_dir/audit/SOURCE_REQUEST.md"
        fi
    fi

    mkdir -p \
        "$distillation_dir/audit/ledgers" \
        "$distillation_dir/audit/skills" \
        "$distillation_dir/runtime-style-pack/techniques"

    temp_request=$(mktemp "$distillation_dir/audit/.source-request.XXXXXX")
    {
        printf '%s\n\n' '# Source Distillation Request'
        printf '%s\n' '- Status: `REGISTERED`'
        printf '%s\n' "- Source slug: \`$source_slug\`"
        printf '%s\n' "- Source path: $source_path"
        printf '%s\n' "- Source format: \`$source_format\`"
        printf '%s\n' "- Source bytes: \`$source_size\`"
        printf '%s\n' "- Source SHA-256: \`$source_hash\`"
        printf '%s\n' "- Registered at: \`$(now_utc)\`"
        printf '%s\n' "- Distillation directory: $distillation_dir"
        printf '%s\n\n' '- Next action: execute Mode A in the repository `SKILL.md` through runtime-pack validation.'
        printf '%s\n' 'The source remains at its original path and must not be copied into this repository.'
    } > "$temp_request"
    mv "$temp_request" "$request_file"

    temp_active=$(mktemp "$workbench_root/.novel/.active-source.XXXXXX")
    cp "$request_file" "$temp_active"
    mv "$temp_active" "$workbench_root/.novel/ACTIVE_SOURCE.md"
    if [ "$previous_active_hash" != "$source_hash" ]; then
        rm -f "$workbench_root/.novel/ACTIVE_PACK.md"
    fi

    printf '%s\n' "SOURCE_SLUG=$source_slug"
    printf '%s\n' "SOURCE_PATH=$source_path"
    printf '%s\n' "SOURCE_SHA256=$source_hash"
    printf '%s\n' "DISTILLATION_DIR=$distillation_dir"
    printf '%s\n' 'NEXT_ACTION=run-mode-a'
}

activate_pack() {
    [ "$#" -eq 1 ] || die "usage: novelctl.sh activate-pack <runtime-style-pack-path>"
    ensure_layout
    pack_path=$(canonical_dir "$1")
    manifest="$pack_path/PACK_MANIFEST.md"
    contract="$pack_path/WRITING_STYLE_CONTRACT.md"
    [ -f "$manifest" ] || die "missing pack manifest: $manifest"
    [ -f "$contract" ] || die "missing style contract: $contract"

    pack_status=$(sed -n 's/^- Status: `\([^`]*\)`.*/\1/p' "$manifest" | sed -n '1p')
    [ "$pack_status" = VALIDATED ] || die "runtime pack is not VALIDATED: ${pack_status:-unknown}"
    pack_id=$(sed -n 's/^- Pack ID: `\([^`]*\)`.*/\1/p' "$manifest" | sed -n '1p')
    pack_version=$(sed -n 's/^- Version: `\([^`]*\)`.*/\1/p' "$manifest" | sed -n '1p')
    [ -n "$pack_id" ] || die "pack manifest has no Pack ID"
    [ -n "$pack_version" ] || die "pack manifest has no Version"

    temp_active=$(mktemp "$workbench_root/.novel/.active-pack.XXXXXX")
    {
        printf '%s\n\n' '# Active Runtime Style Pack'
        printf '%s\n' '- Status: `ACTIVE`'
        printf '%s\n' "- Pack ID: \`$pack_id\`"
        printf '%s\n' "- Version: \`$pack_version\`"
        printf '%s\n' "- Pack path: $pack_path"
        printf '%s\n' "- Activated at: \`$(now_utc)\`"
    } > "$temp_active"
    mv "$temp_active" "$workbench_root/.novel/ACTIVE_PACK.md"

    printf '%s\n' "PACK_ID=$pack_id"
    printf '%s\n' "PACK_VERSION=$pack_version"
    printf '%s\n' "PACK_PATH=$pack_path"
    printf '%s\n' 'NEXT_ACTION=collect-original-theme'
}

scaffold_project() {
    [ "$#" -eq 2 ] || die "usage: novelctl.sh scaffold-project <project-slug> <runtime-style-pack-path>"
    ensure_layout
    project_slug=$1
    case "$project_slug" in
        ''|*[!a-z0-9-]*|-*|*-) die "project slug must use lowercase letters, digits, and internal hyphens" ;;
    esac

    pack_path=$(canonical_dir "$2")
    pack_manifest="$pack_path/PACK_MANIFEST.md"
    [ -f "$pack_manifest" ] || die "missing pack manifest: $pack_manifest"
    [ -f "$pack_path/WRITING_STYLE_CONTRACT.md" ] || die "missing style contract"
    pack_status=$(sed -n 's/^- Status: `\([^`]*\)`.*/\1/p' "$pack_manifest" | sed -n '1p')
    [ "$pack_status" = VALIDATED ] || die "runtime pack is not VALIDATED: ${pack_status:-unknown}"
    [ -f "$workbench_root/knowledge/INDEX.md" ] || die "built-in craft library is missing"

    project_path="$workbench_root/novel-projects/$project_slug"
    [ ! -e "$project_path" ] || die "project already exists: $project_path"

    scaffold_dir=$(mktemp -d "$workbench_root/novel-projects/.$project_slug.scaffold.XXXXXX")
    if ! (
        mkdir -p \
            "$scaffold_dir/style" \
            "$scaffold_dir/craft" \
            "$scaffold_dir/bible" \
            "$scaffold_dir/outline/chapters" \
            "$scaffold_dir/state/characters" \
            "$scaffold_dir/state/entities" \
            "$scaffold_dir/state/chapter-records" \
            "$scaffold_dir/state/summaries" \
            "$scaffold_dir/state/context" \
            "$scaffold_dir/state/revisions" \
            "$scaffold_dir/state/batches" \
            "$scaffold_dir/schemas" \
            "$scaffold_dir/chapters" \
            "$scaffold_dir/.agents/skills/$project_slug-writer"

        cp -R "$pack_path/." "$scaffold_dir/style/"
        cp -R "$workbench_root/knowledge/." "$scaffold_dir/craft/"
        cp "$workbench_root/templates/NOVEL_PROJECT.md.template" "$scaffold_dir/NOVEL_PROJECT.md"
        cp "$workbench_root/templates/AGENTS.project.md.template" "$scaffold_dir/AGENTS.md"
        cp "$workbench_root/templates/STORY_BIBLE.md.template" "$scaffold_dir/bible/STORY_BIBLE.md"
        cp "$workbench_root/templates/MASTER_OUTLINE.md.template" "$scaffold_dir/outline/MASTER_OUTLINE.md"
        cp "$workbench_root/templates/MEMORY_INDEX.md.template" "$scaffold_dir/state/MEMORY_INDEX.md"
        cp "$workbench_root/templates/CURRENT_STATE.md.template" "$scaffold_dir/state/CURRENT_STATE.md"
        cp "$workbench_root/templates/RELATIONSHIP_LEDGER.md.template" "$scaffold_dir/state/RELATIONSHIP_LEDGER.md"
        cp "$workbench_root/templates/KNOWLEDGE_LEDGER.md.template" "$scaffold_dir/state/KNOWLEDGE_LEDGER.md"
        cp "$workbench_root/templates/PLOT_THREADS.md.template" "$scaffold_dir/state/PLOT_THREADS.md"
        cp "$workbench_root/templates/TIMELINE.md.template" "$scaffold_dir/state/TIMELINE.md"
        cp "$workbench_root/templates/CONTINUITY_LEDGER.md.template" "$scaffold_dir/state/CONTINUITY_LEDGER.md"
        cp "$workbench_root/templates/DECISION_LOG.md.template" "$scaffold_dir/state/DECISION_LOG.md"
        cp "$workbench_root/templates/REWARD_LEDGER.md.template" "$scaffold_dir/state/REWARD_LEDGER.md"
        cp "$workbench_root/templates/SERIAL_RHYTHM.md.template" "$scaffold_dir/state/SERIAL_RHYTHM.md"
        cp "$workbench_root/templates/BATCH_INDEX.md.template" "$scaffold_dir/state/BATCH_INDEX.md"
        cp "$workbench_root/schemas/chapter-changes.schema.json" "$scaffold_dir/schemas/chapter-changes.schema.json"
        cp "$workbench_root/templates/PROJECT_WRITER.SKILL.md.template" "$scaffold_dir/.agents/skills/$project_slug-writer/SKILL.md"
    ); then
        rm -r "$scaffold_dir"
        die "failed to create project scaffold"
    fi
    if [ -e "$project_path" ] || ! mv "$scaffold_dir" "$project_path"; then
        rm -r "$scaffold_dir"
        die "could not finalize project scaffold"
    fi

    printf '%s\n' "PROJECT_SLUG=$project_slug"
    printf '%s\n' "PROJECT_PATH=$project_path"
    printf '%s\n' 'NEXT_ACTION=fill-project-templates-and-validate'
}

check_project() {
    project_path=$1
    project_errors=0
    for relative_path in \
        NOVEL_PROJECT.md \
        AGENTS.md \
        style/PACK_MANIFEST.md \
        style/WRITING_STYLE_CONTRACT.md \
        craft/INDEX.md \
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
        state/SERIAL_RHYTHM.md \
        state/BATCH_INDEX.md \
        schemas/chapter-changes.schema.json
    do
        if [ ! -f "$project_path/$relative_path" ]; then
            printf '%s\n' "MISSING project/$relative_path" >&2
            project_errors=$((project_errors + 1))
        elif grep -F '{{' "$project_path/$relative_path" >/dev/null 2>&1; then
            printf '%s\n' "UNRESOLVED project/$relative_path" >&2
            project_errors=$((project_errors + 1))
        fi
    done

    checked_project_id=$(sed -n 's/^- Project ID: `\([^`]*\)`.*/\1/p' "$project_path/NOVEL_PROJECT.md" 2>/dev/null | sed -n '1p')
    if [ -z "$checked_project_id" ] || printf '%s' "$checked_project_id" | grep -F '{{' >/dev/null 2>&1; then
        printf '%s\n' 'INVALID project ID' >&2
        project_errors=$((project_errors + 1))
    else
        writer_file="$project_path/.agents/skills/$checked_project_id-writer/SKILL.md"
        if [ ! -f "$writer_file" ]; then
            printf '%s\n' "MISSING project/.agents/skills/$checked_project_id-writer/SKILL.md" >&2
            project_errors=$((project_errors + 1))
        elif grep -F '{{' "$writer_file" >/dev/null 2>&1; then
            printf '%s\n' 'UNRESOLVED project writer Skill' >&2
            project_errors=$((project_errors + 1))
        fi
    fi

    [ "$project_errors" -eq 0 ]
}

activate_project() {
    [ "$#" -eq 1 ] || die "usage: novelctl.sh activate-project <project-path>"
    ensure_layout
    project_path=$(canonical_dir "$1")
    check_project "$project_path" || die "project configuration is incomplete"

    project_id=$(sed -n 's/^- Project ID: `\([^`]*\)`.*/\1/p' "$project_path/NOVEL_PROJECT.md" | sed -n '1p')
    [ -n "$project_id" ] || project_id=$(basename "$project_path")

    temp_active=$(mktemp "$workbench_root/.novel/.active-project.XXXXXX")
    {
        printf '%s\n\n' '# Active Original Novel Project'
        printf '%s\n' '- Status: `ACTIVE`'
        printf '%s\n' "- Project ID: \`$project_id\`"
        printf '%s\n' "- Project path: $project_path"
        printf '%s\n' "- Activated at: \`$(now_utc)\`"
        printf '%s\n' '- Runtime entry: project-local `.agents/skills/<project>-writer/SKILL.md`'
    } > "$temp_active"
    mv "$temp_active" "$workbench_root/.novel/ACTIVE_PROJECT.md"

    printf '%s\n' "PROJECT_ID=$project_id"
    printf '%s\n' "PROJECT_PATH=$project_path"
    printf '%s\n' 'NEXT_ACTION=use-project-writer'
}

create_batch() {
    [ "$#" -ge 2 ] && [ "$#" -le 4 ] || die "usage: novelctl.sh batch-create <project-path> <chapter-count> [checkpoint-interval] [auto|review]"
    ensure_layout
    project_path=$(canonical_dir "$1")
    check_project "$project_path" || die "project configuration is incomplete"

    requested_count=$2
    checkpoint_interval=${3:-5}
    requested_mode=${4:-auto}
    case "$requested_count" in
        ''|*[!0-9]*) die "chapter count must be an integer" ;;
    esac
    case "$checkpoint_interval" in
        ''|*[!0-9]*) die "checkpoint interval must be an integer" ;;
    esac
    [ "$requested_count" -ge 1 ] && [ "$requested_count" -le 200 ] || die "chapter count must be between 1 and 200"
    [ "$checkpoint_interval" -ge 1 ] || die "checkpoint interval must be at least 1"
    if [ "$checkpoint_interval" -gt "$requested_count" ]; then
        checkpoint_interval=$requested_count
    fi
    case "$requested_mode" in
        auto) batch_mode=AUTO_COMMIT ;;
        review) batch_mode=REVIEW_CHECKPOINTS ;;
        *) die "batch mode must be auto or review" ;;
    esac

    if [ -f "$project_path/state/ACTIVE_BATCH.md" ]; then
        previous_job_path=$(sed -n 's/^- Batch path: //p' "$project_path/state/ACTIVE_BATCH.md" | sed -n '1p')
        if [ -n "$previous_job_path" ] && [ -f "$previous_job_path" ]; then
            previous_status=$(markdown_field "$previous_job_path" Status)
            case "$previous_status" in
                PLANNED|RUNNING|PAUSED|PAUSED_REVIEW)
                    die "unfinished batch exists: $(markdown_field "$previous_job_path" 'Batch ID') ($previous_status)"
                    ;;
            esac
        fi
    fi

    [ -f "$workbench_root/templates/BATCH_PLAN.md.template" ] || die "batch plan template is missing"
    project_id=$(project_id_from_path "$project_path")
    start_chapter=$(project_next_chapter "$project_path")
    batch_id="batch-$(date -u '+%Y%m%dT%H%M%SZ')-$$"
    batch_dir="$project_path/state/batches/$batch_id"
    [ ! -e "$batch_dir" ] || die "batch already exists: $batch_id"
    mkdir -p "$batch_dir"
    job_path="$batch_dir/BATCH_JOB.md"
    {
        printf '%s\n\n' '# Batch Writing Job'
        printf '%s\n' '- Schema version: `1.0`'
        printf '%s\n' "- Batch ID: \`$batch_id\`"
        printf '%s\n' "- Project ID: \`$project_id\`"
        printf '%s\n' '- Status: `PLANNED`'
        printf '%s\n' "- Mode: \`$batch_mode\`"
        printf '%s\n' "- Requested chapters: \`$requested_count\`"
        printf '%s\n' '- Completed chapters: `0`'
        printf '%s\n' "- Start chapter: \`$start_chapter\`"
        printf '%s\n' "- Next chapter: \`$start_chapter\`"
        printf '%s\n' '- Last committed chapter: `none`'
        printf '%s\n' "- Checkpoint interval: \`$checkpoint_interval\`"
        printf '%s\n' '- Stop reason: `none`'
        printf '%s\n' '- Authorization: `explicit batch-writing request`'
        printf '%s\n' "- Created at: \`$(now_utc)\`"
        printf '%s\n' "- Updated at: \`$(now_utc)\`"
        printf '%s\n\n' 'Each successful chapter must be committed to story canon before the next chapter starts. The batch never drafts dependent chapters in parallel.'
    } > "$job_path"
    cp "$workbench_root/templates/BATCH_PLAN.md.template" "$batch_dir/BATCH_PLAN.md"
    write_active_batch "$project_path" "$batch_id" "$job_path" PLANNED
    append_batch_event "$project_path" "$batch_id" created PLANNED "$start_chapter" "$requested_count chapters, mode $batch_mode"

    printf '%s\n' "BATCH_ID=$batch_id"
    printf '%s\n' "BATCH_PATH=$batch_dir"
    printf '%s\n' "START_CHAPTER=$start_chapter"
    printf '%s\n' "CHAPTER_COUNT=$requested_count"
    printf '%s\n' "MODE=$batch_mode"
    printf '%s\n' 'NEXT_ACTION=fill-batch-plan-then-resume'
}

show_batch_status() {
    [ "$#" -ge 1 ] && [ "$#" -le 2 ] || die "usage: novelctl.sh batch-status <project-path> [batch-id]"
    project_path=$(canonical_dir "$1")
    job_path=$(resolve_batch_job "$project_path" "${2:-}")
    sed -n '1,40p' "$job_path"
    printf '%s\n' "BATCH_PLAN=$(dirname "$job_path")/BATCH_PLAN.md"
}

resume_batch() {
    [ "$#" -ge 1 ] && [ "$#" -le 2 ] || die "usage: novelctl.sh batch-resume <project-path> [batch-id]"
    project_path=$(canonical_dir "$1")
    check_project "$project_path" || die "project configuration is incomplete"
    job_path=$(resolve_batch_job "$project_path" "${2:-}")
    batch_dir=$(dirname "$job_path")
    plan_path="$batch_dir/BATCH_PLAN.md"
    [ -s "$plan_path" ] || die "batch plan is missing or empty"
    if grep -F '{{' "$plan_path" >/dev/null 2>&1; then
        die "batch plan still contains unresolved placeholders"
    fi

    batch_id=$(markdown_field "$job_path" 'Batch ID')
    batch_status=$(markdown_field "$job_path" Status)
    next_chapter=$(markdown_field "$job_path" 'Next chapter')
    case "$batch_status" in
        COMPLETE) die "batch is already complete: $batch_id" ;;
        PLANNED|PAUSED|PAUSED_REVIEW|RUNNING) ;;
        *) die "batch cannot resume from status: ${batch_status:-unknown}" ;;
    esac
    [ "$next_chapter" != none ] || die "batch has no next chapter"

    if [ "$batch_status" != RUNNING ]; then
        replace_markdown_field "$job_path" Status RUNNING
        replace_markdown_field "$job_path" 'Stop reason' none
        replace_markdown_field "$job_path" 'Updated at' "$(now_utc)"
        append_batch_event "$project_path" "$batch_id" resumed RUNNING "$next_chapter" 'resume from durable checkpoint'
    fi
    write_active_batch "$project_path" "$batch_id" "$job_path" RUNNING

    printf '%s\n' "BATCH_ID=$batch_id"
    printf '%s\n' 'STATUS=RUNNING'
    printf '%s\n' "RESUME_FROM=$next_chapter"
    printf '%s\n' "COMPLETED=$(markdown_field "$job_path" 'Completed chapters')"
    printf '%s\n' 'NEXT_ACTION=run-project-writer-batch-loop'
}

pause_batch() {
    [ "$#" -ge 2 ] && [ "$#" -le 3 ] || die "usage: novelctl.sh batch-pause <project-path> [batch-id] <reason>"
    project_path=$(canonical_dir "$1")
    if [ "$#" -eq 2 ]; then
        requested_batch_id=
        pause_reason=$2
    else
        requested_batch_id=$2
        pause_reason=$3
    fi
    job_path=$(resolve_batch_job "$project_path" "$requested_batch_id")
    batch_id=$(markdown_field "$job_path" 'Batch ID')
    batch_status=$(markdown_field "$job_path" Status)
    case "$batch_status" in
        RUNNING|PLANNED|PAUSED_REVIEW) ;;
        PAUSED) ;;
        *) die "batch cannot pause from status: ${batch_status:-unknown}" ;;
    esac
    replace_markdown_field "$job_path" Status PAUSED
    replace_markdown_field "$job_path" 'Stop reason' "$pause_reason"
    replace_markdown_field "$job_path" 'Updated at' "$(now_utc)"
    next_chapter=$(markdown_field "$job_path" 'Next chapter')
    write_active_batch "$project_path" "$batch_id" "$job_path" PAUSED
    append_batch_event "$project_path" "$batch_id" paused PAUSED "$next_chapter" "$pause_reason"
    printf '%s\n' "BATCH_ID=$batch_id"
    printf '%s\n' 'STATUS=PAUSED'
    printf '%s\n' "RESUME_FROM=$next_chapter"
}

validate_committed_chapter() {
    project_path=$1
    project_id=$2
    chapter_id=$3
    chapter_file="$project_path/chapters/$chapter_id.md"
    record_file="$project_path/state/chapter-records/$chapter_id.md"
    changes_file="$project_path/state/chapter-records/$chapter_id.changes.json"
    [ -s "$chapter_file" ] || die "accepted chapter file is missing or empty: $chapter_file"
    [ -s "$record_file" ] || die "chapter record is missing or empty: $record_file"
    [ -s "$changes_file" ] || die "chapter changes JSON is missing or empty: $changes_file"
    if grep -F '{{' "$record_file" "$changes_file" >/dev/null 2>&1; then
        die "chapter record or changes JSON contains unresolved placeholders: $chapter_id"
    fi
    grep -F -- '- Status: `ACCEPTED`' "$record_file" >/dev/null 2>&1 || die "chapter record is not ACCEPTED: $record_file"
    grep -F "\"project_id\": \"$project_id\"" "$changes_file" >/dev/null 2>&1 || die "changes JSON project_id mismatch: $changes_file"
    grep -F "\"chapter_id\": \"$chapter_id\"" "$changes_file" >/dev/null 2>&1 || die "changes JSON chapter_id mismatch: $changes_file"
    grep -F '"status": "ACCEPTED"' "$changes_file" >/dev/null 2>&1 || die "changes JSON is not ACCEPTED: $changes_file"

    for checkpoint_file in \
        "$project_path/NOVEL_PROJECT.md" \
        "$project_path/state/CURRENT_STATE.md" \
        "$project_path/state/MEMORY_INDEX.md"
    do
        accepted_through=$(plain_list_field "$checkpoint_file" 'Accepted through')
        [ "$accepted_through" = "$chapter_id" ] || die "checkpoint not refreshed through $chapter_id: $checkpoint_file"
    done
}

checkpoint_batch() {
    [ "$#" -eq 4 ] || die "usage: novelctl.sh batch-checkpoint <project-path> <batch-id> <committed-chapter-id> <next-batch-chapter-id|none>"
    project_path=$(canonical_dir "$1")
    check_project "$project_path" || die "project configuration is incomplete"
    requested_batch_id=$2
    committed_chapter=$3
    next_batch_chapter=$4
    case "$committed_chapter:$next_batch_chapter" in
        *[!a-zA-Z0-9:-]*) die "chapter IDs may contain only letters, digits, and hyphens" ;;
    esac

    job_path=$(resolve_batch_job "$project_path" "$requested_batch_id")
    batch_id=$(markdown_field "$job_path" 'Batch ID')
    batch_status=$(markdown_field "$job_path" Status)
    expected_chapter=$(markdown_field "$job_path" 'Next chapter')
    last_committed=$(markdown_field "$job_path" 'Last committed chapter')
    if [ "$last_committed" = "$committed_chapter" ]; then
        printf '%s\n' "BATCH_ID=$batch_id"
        printf '%s\n' 'CHECKPOINT=ALREADY_RECORDED'
        printf '%s\n' "NEXT_CHAPTER=$(markdown_field "$job_path" 'Next chapter')"
        return
    fi
    [ "$batch_status" = RUNNING ] || die "batch checkpoint requires RUNNING status, found: ${batch_status:-unknown}"
    [ "$expected_chapter" = "$committed_chapter" ] || die "expected $expected_chapter, cannot checkpoint $committed_chapter"

    project_id=$(project_id_from_path "$project_path")
    validate_committed_chapter "$project_path" "$project_id" "$committed_chapter"
    completed=$(markdown_field "$job_path" 'Completed chapters')
    requested=$(markdown_field "$job_path" 'Requested chapters')
    checkpoint_interval=$(markdown_field "$job_path" 'Checkpoint interval')
    batch_mode=$(markdown_field "$job_path" Mode)
    new_completed=$((completed + 1))
    [ "$new_completed" -le "$requested" ] || die "batch completion exceeds requested chapter count"

    if [ "$new_completed" -eq "$requested" ]; then
        [ "$next_batch_chapter" = none ] || die "final batch checkpoint must use next chapter 'none'"
        new_status=COMPLETE
        checkpoint_due=yes
    else
        [ "$next_batch_chapter" != none ] || die "unfinished batch requires the next chapter ID"
        project_next=$(project_next_chapter "$project_path")
        [ "$project_next" = "$next_batch_chapter" ] || die "project next chapter is $project_next, not $next_batch_chapter"
        checkpoint_due=no
        if [ $((new_completed % checkpoint_interval)) -eq 0 ]; then
            checkpoint_due=yes
        fi
        if [ "$batch_mode" = REVIEW_CHECKPOINTS ] && [ "$checkpoint_due" = yes ]; then
            new_status=PAUSED_REVIEW
        else
            new_status=RUNNING
        fi
    fi

    replace_markdown_field "$job_path" 'Completed chapters' "$new_completed"
    replace_markdown_field "$job_path" 'Last committed chapter' "$committed_chapter"
    replace_markdown_field "$job_path" 'Next chapter' "$next_batch_chapter"
    replace_markdown_field "$job_path" Status "$new_status"
    replace_markdown_field "$job_path" 'Stop reason' none
    replace_markdown_field "$job_path" 'Updated at' "$(now_utc)"
    write_active_batch "$project_path" "$batch_id" "$job_path" "$new_status"
    append_batch_event "$project_path" "$batch_id" checkpoint "$new_status" "$committed_chapter" "$new_completed/$requested; next $next_batch_chapter"

    printf '%s\n' "BATCH_ID=$batch_id"
    printf '%s\n' "STATUS=$new_status"
    printf '%s\n' "COMPLETED=$new_completed"
    printf '%s\n' "REQUESTED=$requested"
    printf '%s\n' "NEXT_CHAPTER=$next_batch_chapter"
    printf '%s\n' "CHECKPOINT_DUE=$checkpoint_due"
}

show_status() {
    ensure_layout
    printf '%s\n' 'WORKBENCH=READY'
    if [ -f "$workbench_root/.novel/ACTIVE_SOURCE.md" ]; then
        sed -n '1,40p' "$workbench_root/.novel/ACTIVE_SOURCE.md"
    else
        printf '%s\n' 'ACTIVE_SOURCE=none'
    fi
    if [ -f "$workbench_root/.novel/ACTIVE_PACK.md" ]; then
        sed -n '1,40p' "$workbench_root/.novel/ACTIVE_PACK.md"
    else
        printf '%s\n' 'ACTIVE_PACK=none'
    fi
    if [ -f "$workbench_root/.novel/ACTIVE_PROJECT.md" ]; then
        sed -n '1,40p' "$workbench_root/.novel/ACTIVE_PROJECT.md"
        active_project=$(sed -n 's/^- Project path: //p' "$workbench_root/.novel/ACTIVE_PROJECT.md" | sed -n '1p')
        if [ -n "$active_project" ] && [ -f "$active_project/state/ACTIVE_BATCH.md" ]; then
            sed -n '1,20p' "$active_project/state/ACTIVE_BATCH.md"
        fi
    else
        printf '%s\n' 'ACTIVE_PROJECT=none'
    fi
}

doctor() {
    ensure_layout
    errors=0
    for relative_path in \
        AGENTS.md \
        SKILL.md \
        knowledge/INDEX.md \
        schemas/chapter-changes.schema.json \
        references/10-workspace-orchestration.md \
        references/11-long-form-memory-system.md \
        references/12-batch-writing.md \
        scripts/novelctl.sh
    do
        if [ ! -f "$workbench_root/$relative_path" ]; then
            printf '%s\n' "MISSING workbench/$relative_path" >&2
            errors=$((errors + 1))
        fi
    done

    if [ -f "$workbench_root/.novel/ACTIVE_SOURCE.md" ]; then
        active_source=$(sed -n 's/^- Source path: //p' "$workbench_root/.novel/ACTIVE_SOURCE.md" | sed -n '1p')
        if [ -z "$active_source" ] || [ ! -r "$active_source" ]; then
            printf '%s\n' 'INVALID active source pointer' >&2
            errors=$((errors + 1))
        fi
    fi

    if [ -f "$workbench_root/.novel/ACTIVE_PACK.md" ]; then
        active_pack=$(sed -n 's/^- Pack path: //p' "$workbench_root/.novel/ACTIVE_PACK.md" | sed -n '1p')
        if [ -z "$active_pack" ] || [ ! -f "$active_pack/PACK_MANIFEST.md" ] || [ ! -f "$active_pack/WRITING_STYLE_CONTRACT.md" ]; then
            printf '%s\n' 'INVALID active runtime pack pointer' >&2
            errors=$((errors + 1))
        else
            active_pack_status=$(sed -n 's/^- Status: `\([^`]*\)`.*/\1/p' "$active_pack/PACK_MANIFEST.md" | sed -n '1p')
            if [ "$active_pack_status" != VALIDATED ]; then
                printf '%s\n' 'INVALID active runtime pack status' >&2
                errors=$((errors + 1))
            fi
        fi
    fi

    if [ -f "$workbench_root/.novel/ACTIVE_PROJECT.md" ]; then
        active_project=$(sed -n 's/^- Project path: //p' "$workbench_root/.novel/ACTIVE_PROJECT.md" | sed -n '1p')
        if [ -z "$active_project" ] || [ ! -d "$active_project" ]; then
            printf '%s\n' 'INVALID active project pointer' >&2
            errors=$((errors + 1))
        elif ! check_project "$active_project"; then
            errors=$((errors + 1))
        elif [ -f "$active_project/state/ACTIVE_BATCH.md" ]; then
            active_batch_path=$(sed -n 's/^- Batch path: //p' "$active_project/state/ACTIVE_BATCH.md" | sed -n '1p')
            if [ -z "$active_batch_path" ] || [ ! -f "$active_batch_path" ]; then
                printf '%s\n' 'INVALID active batch pointer' >&2
                errors=$((errors + 1))
            else
                resolved_active_batch=$(canonical_file "$active_batch_path")
                case "$resolved_active_batch" in
                    "$active_project"/state/batches/*/BATCH_JOB.md)
                        checked_batch_status=$(markdown_field "$resolved_active_batch" Status)
                        case "$checked_batch_status" in
                            PLANNED|RUNNING|PAUSED|PAUSED_REVIEW|COMPLETE) ;;
                            *)
                                printf '%s\n' 'INVALID active batch status' >&2
                                errors=$((errors + 1))
                                ;;
                        esac
                        checked_batch_plan="$(dirname "$resolved_active_batch")/BATCH_PLAN.md"
                        if [ "$checked_batch_status" = RUNNING ] && { [ ! -s "$checked_batch_plan" ] || grep -F '{{' "$checked_batch_plan" >/dev/null 2>&1; }; then
                            printf '%s\n' 'INVALID running batch plan' >&2
                            errors=$((errors + 1))
                        fi
                        ;;
                    *)
                        printf '%s\n' 'INVALID active batch path' >&2
                        errors=$((errors + 1))
                        ;;
                esac
            fi
        fi
    fi

    if [ "$errors" -ne 0 ]; then
        die "$errors configuration problem(s) found"
    fi
    printf '%s\n' 'DOCTOR=PASS'
}

usage() {
    printf '%s\n' 'Usage:'
    printf '%s\n' '  novelctl.sh bootstrap'
    printf '%s\n' '  novelctl.sh register-source <novel-path>'
    printf '%s\n' '  novelctl.sh activate-pack <runtime-style-pack-path>'
    printf '%s\n' '  novelctl.sh scaffold-project <project-slug> <runtime-style-pack-path>'
    printf '%s\n' '  novelctl.sh activate-project <project-path>'
    printf '%s\n' '  novelctl.sh batch-create <project-path> <chapter-count> [checkpoint-interval] [auto|review]'
    printf '%s\n' '  novelctl.sh batch-status <project-path> [batch-id]'
    printf '%s\n' '  novelctl.sh batch-resume <project-path> [batch-id]'
    printf '%s\n' '  novelctl.sh batch-pause <project-path> [batch-id] <reason>'
    printf '%s\n' '  novelctl.sh batch-checkpoint <project-path> <batch-id> <committed-chapter-id> <next-batch-chapter-id|none>'
    printf '%s\n' '  novelctl.sh status'
    printf '%s\n' '  novelctl.sh doctor'
}

command_name=${1:-help}
if [ "$#" -gt 0 ]; then
    shift
fi

case "$command_name" in
    bootstrap) [ "$#" -eq 0 ] || die "bootstrap accepts no arguments"; ensure_layout; printf '%s\n' 'WORKBENCH=READY' ;;
    register-source) register_source "$@" ;;
    activate-pack) activate_pack "$@" ;;
    scaffold-project) scaffold_project "$@" ;;
    activate-project) activate_project "$@" ;;
    batch-create) create_batch "$@" ;;
    batch-status) show_batch_status "$@" ;;
    batch-resume) resume_batch "$@" ;;
    batch-pause) pause_batch "$@" ;;
    batch-checkpoint) checkpoint_batch "$@" ;;
    status) [ "$#" -eq 0 ] || die "status accepts no arguments"; show_status ;;
    doctor) [ "$#" -eq 0 ] || die "doctor accepts no arguments"; doctor ;;
    help|-h|--help) usage ;;
    *) usage >&2; die "unknown command: $command_name" ;;
esac
