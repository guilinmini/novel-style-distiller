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
                printf '%s\n' '- Schema version: `1.0`'
                printf '%s\n' '- Status: `READY`'
                printf '%s\n' '- Active source pointer: `.novel/ACTIVE_SOURCE.md`'
                printf '%s\n' '- Active project pointer: `.novel/ACTIVE_PROJECT.md`'
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
        state/DECISION_LOG.md
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
        references/10-workspace-orchestration.md \
        references/11-long-form-memory-system.md \
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
    status) [ "$#" -eq 0 ] || die "status accepts no arguments"; show_status ;;
    doctor) [ "$#" -eq 0 ] || die "doctor accepts no arguments"; doctor ;;
    help|-h|--help) usage ;;
    *) usage >&2; die "unknown command: $command_name" ;;
esac
