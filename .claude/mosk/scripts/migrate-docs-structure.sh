#!/usr/bin/env bash

set -e

KEEP_OLD=false
DRY_RUN=false

for arg in "$@"; do
    case "$arg" in
        --keep-old)
            KEEP_OLD=true
            ;;
        --dry-run)
            DRY_RUN=true
            ;;
        --help|-h)
            cat <<'EOF'
Usage: migrate-docs-structure.sh [--keep-old] [--dry-run] [--help]

Migrates a consuming project's `docs/` layout to the MOSK v2 structure:

  docs/
    discovery/            (new)
    prd/                  (scaffold + migrate existing docs/prd.md)
    architecture/         (scaffold + migrate existing docs/architecture.md)
    ui/                   (new + migrate docs/front-end-spec.md if present)
    qa/gates/             (scaffold)
    specs/                (scaffold + move docs/stories/ into per-spec stories/)

Also:
  - Creates docs/index.md via the `index-docs` task convention.
  - Moves docs/brainstorming-session-results.md into docs/discovery/brainstorming/.
  - Moves docs/project-architecture.md into docs/architecture/.
  - Moves docs/brief.md, docs/market-research.md, docs/competitor-analysis.md
    into docs/discovery/.
  - Moves docs/ui-architecture.md into docs/architecture/.
  - Rewrites .claude/mosk/core-config.yaml to the v2 schema.
    A backup is saved as .claude/mosk/core-config.yaml.legacy.
  - Creates spec-meta.yaml retroactively for each existing
    docs/specs/*/ folder (parsed from folder name).

OPTIONS:
  --keep-old   Copy instead of move: preserves docs/prd.md, docs/stories/, etc.
  --dry-run    Print planned actions; do not write, move, or delete anything.
  --help, -h   Show this help message.

After running, re-run `bash .claude/mosk/scripts/link-codex-skills.sh`
to refresh .codex/ symlinks if you use Codex.

The script is idempotent: running it a second time on an up-to-date
project is a no-op.
EOF
            exit 0
            ;;
        *)
            echo "ERROR: Unknown option '$arg'. Use --help for usage information." >&2
            exit 1
            ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
DOCS_DIR="$INSTALL_ROOT/docs"
CONFIG_FILE="$INSTALL_ROOT/.claude/mosk/core-config.yaml"

if $DRY_RUN; then
    echo "Mode: DRY RUN (no changes will be made)"
elif $KEEP_OLD; then
    echo "Mode: migrate + KEEP old files (copy instead of move)"
else
    echo "Mode: migrate + REPLACE old files (move)"
fi
echo "Docs dir: $DOCS_DIR"
echo

# ---------- helpers ----------

log()      { echo "$1"; }
act()      { $DRY_RUN && echo "would   $*" || { echo "$*"; eval "$@"; }; }
ensure_dir() {
    local d="$1" label="$2"
    if [[ -d "$d" ]]; then
        echo "keep    $label  ($d)"
    else
        if $DRY_RUN; then
            echo "would   create $label  ($d)"
        else
            mkdir -p "$d"
            echo "create  $label  ($d)"
        fi
    fi
}

write_if_missing() {
    local path="$1"
    local content="$2"
    if [[ -f "$path" ]]; then
        echo "keep    $path (already exists)"
        return
    fi
    if $DRY_RUN; then
        echo "would   write $path"
    else
        cat > "$path" <<<"$content"
        echo "create  $path"
    fi
}

move_or_copy() {
    local src="$1" dst="$2" label="$3"
    if [[ ! -e "$src" ]]; then
        return 0
    fi
    if [[ -e "$dst" ]]; then
        echo "skip    $label ($dst already exists)"
        return 0
    fi
    if $KEEP_OLD; then
        if $DRY_RUN; then
            echo "would   copy    $src -> $dst"
        else
            cp -R "$src" "$dst"
            echo "copy    $src -> $dst"
        fi
    else
        if $DRY_RUN; then
            echo "would   move    $src -> $dst"
        else
            mv "$src" "$dst"
            echo "move    $src -> $dst"
        fi
    fi
}

# ---------- detection ----------

NEEDS_MIGRATION=false
check_legacy_state() {
    local reason=""
    [[ -f "$DOCS_DIR/prd.md" ]] && reason+=" docs/prd.md"
    [[ -f "$DOCS_DIR/architecture.md" ]] && reason+=" docs/architecture.md"
    [[ -d "$DOCS_DIR/stories" ]] && reason+=" docs/stories/"
    [[ -f "$DOCS_DIR/brainstorming-session-results.md" ]] && reason+=" docs/brainstorming-session-results.md"
    [[ -f "$DOCS_DIR/front-end-spec.md" ]] && reason+=" docs/front-end-spec.md"
    [[ -f "$DOCS_DIR/project-architecture.md" ]] && reason+=" docs/project-architecture.md"
    [[ -f "$DOCS_DIR/brief.md" ]] && reason+=" docs/brief.md"
    [[ -f "$DOCS_DIR/market-research.md" ]] && reason+=" docs/market-research.md"
    [[ -f "$DOCS_DIR/competitor-analysis.md" ]] && reason+=" docs/competitor-analysis.md"
    [[ -f "$DOCS_DIR/ui-architecture.md" ]] && reason+=" docs/ui-architecture.md"
    if [[ -f "$CONFIG_FILE" ]]; then
        if grep -qE "^(prdFile|architectureFile|prdSharded|prdShardedLocation|architectureSharded|architectureShardedLocation|devStoryLocation)[[:space:]]*:" "$CONFIG_FILE"; then
            reason+=" legacy-core-config"
        fi
    fi
    # Also migrate if docs/ exists but v2 skeleton is missing
    if [[ -d "$DOCS_DIR" ]]; then
        for sub in discovery prd architecture ui qa/gates specs; do
            [[ -d "$DOCS_DIR/$sub" ]] || reason+=" missing-$sub"
        done
    fi
    if [[ -n "$reason" ]]; then
        NEEDS_MIGRATION=true
        echo "Legacy state detected:$reason"
    fi
}

check_legacy_state
if ! $NEEDS_MIGRATION; then
    echo "Nothing to migrate. Structure already up to date."
    exit 0
fi
echo

# ---------- phase 1: scaffold canonical docs/ ----------

echo "=== phase 1: scaffold canonical docs/ ==="
ensure_dir "$DOCS_DIR"                    "docs/"
ensure_dir "$DOCS_DIR/discovery"          "docs/discovery/"
ensure_dir "$DOCS_DIR/discovery/brainstorming" "docs/discovery/brainstorming/"
ensure_dir "$DOCS_DIR/prd"                "docs/prd/"
ensure_dir "$DOCS_DIR/architecture"       "docs/architecture/"
ensure_dir "$DOCS_DIR/architecture/adr"   "docs/architecture/adr/"
ensure_dir "$DOCS_DIR/ui"                 "docs/ui/"
ensure_dir "$DOCS_DIR/ui/flows"           "docs/ui/flows/"
ensure_dir "$DOCS_DIR/qa/gates"           "docs/qa/gates/"
ensure_dir "$DOCS_DIR/specs"              "docs/specs/"
echo

# ---------- phase 2: migrate monolithic PRD / architecture ----------

echo "=== phase 2: migrate monolithic PRD / architecture ==="
move_or_copy "$DOCS_DIR/prd.md"          "$DOCS_DIR/prd/raw.md"          "PRD monolith"
move_or_copy "$DOCS_DIR/architecture.md" "$DOCS_DIR/architecture/raw.md" "Architecture monolith"
echo

# ---------- phase 3: migrate loose files ----------

echo "=== phase 3: migrate loose files ==="
move_or_copy "$DOCS_DIR/brainstorming-session-results.md" \
             "$DOCS_DIR/discovery/brainstorming/brainstorming-session-results.md" \
             "brainstorming results"
move_or_copy "$DOCS_DIR/front-end-spec.md" \
             "$DOCS_DIR/ui/index.md" \
             "front-end spec -> ui/index.md"
move_or_copy "$DOCS_DIR/project-architecture.md" \
             "$DOCS_DIR/architecture/project-architecture.md" \
             "project-architecture -> architecture/"
move_or_copy "$DOCS_DIR/brief.md" \
             "$DOCS_DIR/discovery/brief.md" \
             "brief -> discovery/"
move_or_copy "$DOCS_DIR/market-research.md" \
             "$DOCS_DIR/discovery/market-research.md" \
             "market-research -> discovery/"
move_or_copy "$DOCS_DIR/competitor-analysis.md" \
             "$DOCS_DIR/discovery/competitor-analysis.md" \
             "competitor-analysis -> discovery/"
move_or_copy "$DOCS_DIR/ui-architecture.md" \
             "$DOCS_DIR/architecture/ui-architecture.md" \
             "ui-architecture -> architecture/"
echo

# ---------- phase 4: migrate stories ----------

echo "=== phase 4: migrate stories ==="
if [[ -d "$DOCS_DIR/stories" ]]; then
    orphan_dir="$DOCS_DIR/specs/_orphan-stories"
    moved=0
    orphaned=0
    shopt -s nullglob
    for story in "$DOCS_DIR/stories"/*.md; do
        [[ -f "$story" ]] || continue
        fname=$(basename "$story")
        epic_prefix=""
        if [[ "$fname" =~ ^epic-([0-9]+)- ]]; then
            epic_prefix="${BASH_REMATCH[1]}"
        elif [[ "$fname" =~ ^([0-9]+)\.([0-9]+)\. ]]; then
            epic_prefix="${BASH_REMATCH[1]}"
        fi
        target_spec=""
        if [[ -n "$epic_prefix" ]]; then
            pad=$(printf "%03d" "$epic_prefix")
            for s in "$DOCS_DIR/specs/$pad-"*; do
                if [[ -d "$s" ]]; then
                    target_spec="$s"
                    break
                fi
            done
        fi
        if [[ -n "$target_spec" ]]; then
            dst_dir="$target_spec/stories"
            ensure_dir "$dst_dir" "stories dir" >/dev/null
            move_or_copy "$story" "$dst_dir/$fname" "story -> spec"
            moved=$((moved + 1))
        else
            ensure_dir "$orphan_dir" "orphan stories" >/dev/null
            move_or_copy "$story" "$orphan_dir/$fname" "story -> orphan"
            orphaned=$((orphaned + 1))
        fi
    done
    shopt -u nullglob
    echo "stories moved: $moved, orphaned: $orphaned"
    # Remove empty docs/stories/ if we moved everything out
    if ! $KEEP_OLD && ! $DRY_RUN; then
        if [[ -d "$DOCS_DIR/stories" ]] && [[ -z $(ls -A "$DOCS_DIR/stories") ]]; then
            rmdir "$DOCS_DIR/stories" && echo "remove  docs/stories/ (empty after migration)"
        fi
    fi
else
    echo "no docs/stories/ — skipping"
fi
echo

# ---------- phase 5: scaffold docs/ READMEs (only if missing) ----------

echo "=== phase 5: scaffold domain READMEs ==="
write_if_missing "$DOCS_DIR/discovery/README.md" "# Discovery

Written by \`mosk-analyst\`. Base-level artifacts (project-wide): brief,
market research, competitor analysis, brainstorming results.

Feature-scoped discovery goes inside the relevant spec:
\`docs/specs/{id}/discovery/\`."
write_if_missing "$DOCS_DIR/prd/index.md" "# Product Requirements

Sharded PRD. Use \`shard-doc\` on a \`docs/prd/raw.md\` monolith to
generate section files alongside this index."
write_if_missing "$DOCS_DIR/architecture/index.md" "# Architecture

Sharded architecture docs. ADRs live under \`docs/architecture/adr/\`.
Feature-scoped decisions go in \`docs/specs/{id}/architecture/\` and
promote here at archive time via \`promote:\` front-matter."
write_if_missing "$DOCS_DIR/ui/index.md" "# UI

UX flows and wireframes (\`mosk-ux-expert\`) and design system / styles
(\`mosk-ui-expert\`) coexist here. Feature-scoped UI goes in
\`docs/specs/{id}/ui/\` and promotes here at archive time."
write_if_missing "$DOCS_DIR/qa/README.md" "# QA

Quality gate records live in \`gates/\`. Per-spec gates live in
\`docs/specs/{id}/gate.yaml\`."
echo

# ---------- phase 6: spec-meta.yaml retroactive ----------

echo "=== phase 6: retroactive spec-meta.yaml ==="
now=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
retro=0
skipped=0
shopt -s nullglob
for dir in "$DOCS_DIR/specs"/*/; do
    dir="${dir%/}"
    base=$(basename "$dir")
    [[ "$base" == "archive" ]] && continue
    [[ "$base" == "_orphan-stories" ]] && continue
    if [[ -f "$dir/spec-meta.yaml" ]]; then
        skipped=$((skipped + 1))
        continue
    fi
    # Parse "{###}-{type}-{rest}" or "{###}-{rest}"
    spec_number="000"
    spec_type="feature"
    if [[ "$base" =~ ^([0-9]{3})-([a-z]+)- ]]; then
        spec_number="${BASH_REMATCH[1]}"
        spec_type="${BASH_REMATCH[2]}"
    elif [[ "$base" =~ ^([0-9]{3})- ]]; then
        spec_number="${BASH_REMATCH[1]}"
    fi
    # Infer current_phase
    phase="specify"
    [[ -f "$dir/plan.md" ]] && phase="plan"
    [[ -f "$dir/tasks.md" ]] && phase="tasks"
    [[ -f "$dir/gate.yaml" ]] && phase="qa-gate"
    # Use folder mtime as created_at approximation
    if stat -f%Sm -t "%Y-%m-%dT%H:%M:%SZ" "$dir" >/dev/null 2>&1; then
        folder_mtime=$(stat -f%Sm -t "%Y-%m-%dT%H:%M:%SZ" "$dir")
    else
        folder_mtime="$now"
    fi
    content="# generated by migrate-docs-structure.sh — please review
spec_number: \"$spec_number\"
spec_id: \"$base\"
type: \"$spec_type\"
branch: \"$base\"
created_at: \"$folder_mtime\"
created_by: \"\"
status: active
current_phase: $phase
last_phase_change: \"$now\""
    if $DRY_RUN; then
        echo "would   create $dir/spec-meta.yaml (phase=$phase, type=$spec_type)"
    else
        echo "$content" > "$dir/spec-meta.yaml"
        echo "create  $dir/spec-meta.yaml"
    fi
    retro=$((retro + 1))
done
# Same for archived specs
for dir in "$DOCS_DIR/specs/archive"/*/; do
    dir="${dir%/}"
    [[ -d "$dir" ]] || continue
    base=$(basename "$dir")
    if [[ -f "$dir/spec-meta.yaml" ]]; then
        skipped=$((skipped + 1))
        continue
    fi
    spec_number="000"
    spec_type="feature"
    if [[ "$base" =~ ^([0-9]{3})-([a-z]+)- ]]; then
        spec_number="${BASH_REMATCH[1]}"
        spec_type="${BASH_REMATCH[2]}"
    elif [[ "$base" =~ ^([0-9]{3})- ]]; then
        spec_number="${BASH_REMATCH[1]}"
    fi
    if stat -f%Sm -t "%Y-%m-%dT%H:%M:%SZ" "$dir" >/dev/null 2>&1; then
        folder_mtime=$(stat -f%Sm -t "%Y-%m-%dT%H:%M:%SZ" "$dir")
    else
        folder_mtime="$now"
    fi
    content="# generated by migrate-docs-structure.sh — please review
spec_number: \"$spec_number\"
spec_id: \"$base\"
type: \"$spec_type\"
branch: \"$base\"
created_at: \"$folder_mtime\"
created_by: \"\"
status: archived
current_phase: archived
archived_at: \"$folder_mtime\""
    if $DRY_RUN; then
        echo "would   create $dir/spec-meta.yaml (archived)"
    else
        echo "$content" > "$dir/spec-meta.yaml"
        echo "create  $dir/spec-meta.yaml (archived)"
    fi
    retro=$((retro + 1))
done
shopt -u nullglob
echo "retroactive spec-meta created: $retro, already existed: $skipped"
echo

# ---------- phase 7: rewrite core-config.yaml ----------

echo "=== phase 7: rewrite core-config.yaml ==="
if [[ -f "$CONFIG_FILE" ]]; then
    if grep -qE "^(prdFile|architectureFile|prdSharded|prdShardedLocation|architectureSharded|architectureShardedLocation|devStoryLocation)[[:space:]]*:" "$CONFIG_FILE"; then
        backup="$CONFIG_FILE.legacy"
        if [[ -f "$backup" ]]; then
            echo "keep    $backup (backup already present)"
        else
            if $DRY_RUN; then
                echo "would   backup $CONFIG_FILE -> $backup"
            else
                cp "$CONFIG_FILE" "$backup"
                echo "backup  $CONFIG_FILE -> $backup"
            fi
        fi

        new_content='markdownExploder: true
specs:
  root: docs/specs
  archive: docs/specs/archive
  storiesSubdir: stories
  testsSubdir: tests
  gateFile: gate.yaml
  metaFile: spec-meta.yaml
discovery:
  root: docs/discovery
prd:
  root: docs/prd
  indexFile: docs/prd/index.md
architecture:
  root: docs/architecture
  indexFile: docs/architecture/index.md
  adrDir: docs/architecture/adr
ui:
  root: docs/ui
  indexFile: docs/ui/index.md
qa:
  qaLocation: docs/qa
  gatesDir: docs/qa/gates
  assessmentsDir: docs/qa/assessments
index:
  file: docs/index.md
  template: .claude/mosk/templates/docs-index-tmpl.md
promotion:
  defaults:
    "specs/*/architecture/adr-*.md": { target: docs/architecture/adr/, mode: copy }
    "specs/*/ui/flows/*.md":          { target: docs/ui/flows/,       mode: copy }
    "specs/*/prd-delta.md":           { target: docs/prd/,             mode: manual }
slashPrefix: MOSK
'
        if $DRY_RUN; then
            echo "would   rewrite $CONFIG_FILE to v2 schema"
        else
            echo "$new_content" > "$CONFIG_FILE"
            echo "rewrite $CONFIG_FILE (v2 schema)"
        fi
    else
        echo "keep    $CONFIG_FILE (already v2-compatible)"
    fi
else
    echo "skip    $CONFIG_FILE (not present — not a MOSK install?)"
fi
echo

# ---------- phase 8: regenerate docs/index.md ----------

echo "=== phase 8: docs/index.md ==="
if [[ -f "$DOCS_DIR/index.md" ]]; then
    echo "keep    $DOCS_DIR/index.md (exists — re-run /mosk-dev index-docs to refresh)"
else
    placeholder="# Project Documentation Index

Last updated: $now

_This index will be populated automatically by the \`index-docs\` task.
Run \`/mosk-dev index-docs\` or let any pipeline task refresh it._
"
    if $DRY_RUN; then
        echo "would   create placeholder $DOCS_DIR/index.md"
    else
        echo "$placeholder" > "$DOCS_DIR/index.md"
        echo "create  $DOCS_DIR/index.md (placeholder; will be populated by index-docs)"
    fi
fi
echo

# ---------- summary ----------

echo "=== summary ==="
echo "Migration complete."
if $DRY_RUN; then
    echo "DRY RUN — no changes were persisted."
else
    echo "Next steps:"
    echo "  1. Review docs/specs/_orphan-stories/ if any stories didn't auto-match a spec."
    echo "  2. Review retroactive spec-meta.yaml files (marked with 'please review')."
    echo "  3. Run /mosk-dev index-docs to populate docs/index.md."
    echo "  4. If Codex is in use, run: bash .claude/mosk/scripts/link-codex-skills.sh"
fi
