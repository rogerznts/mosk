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
Usage: migrate-ctx-skills-to-rules.sh [--keep-old] [--dry-run] [--help]

Converts legacy .claude/skills/ctx-*/SKILL.md files into .claude/rules/*.md.

For each ctx-<name> skill found, writes .claude/rules/<name>.md containing
the SKILL.md body stripped of its YAML frontmatter. By default, deletes the
original ctx-* skill directory after a successful conversion.

OPTIONS:
  --keep-old   Keep the original ctx-* skill directories after conversion.
  --dry-run    Print planned actions without writing or deleting anything.
  --help, -h   Show this help message.

After running, re-run `bash .claude/mosk/scripts/link-codex-skills.sh` to
refresh `.codex/rules/` symlinks for Codex CLI.
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
SKILLS_DIR="$INSTALL_ROOT/.claude/skills"
RULES_DIR="$INSTALL_ROOT/.claude/rules"
CODEX_SKILLS_DIR="$INSTALL_ROOT/.codex/skills"

if [[ ! -d "$SKILLS_DIR" ]]; then
    echo "No .claude/skills/ directory found at $SKILLS_DIR. Nothing to migrate."
    exit 0
fi

# Detect legacy ctx-* skills
legacy_dirs=()
shopt -s nullglob
for d in "$SKILLS_DIR"/ctx-*/; do
    legacy_dirs+=("$d")
done
shopt -u nullglob

if [[ ${#legacy_dirs[@]} -eq 0 ]]; then
    echo "No legacy ctx-* skills found in $SKILLS_DIR. Nothing to migrate."
    exit 0
fi

echo "Found ${#legacy_dirs[@]} legacy ctx-* skill(s) in $SKILLS_DIR"
echo "Target rules dir: $RULES_DIR"
if $DRY_RUN; then
    echo "Mode: DRY RUN (no changes)"
elif $KEEP_OLD; then
    echo "Mode: convert + KEEP old ctx-* skills"
else
    echo "Mode: convert + DELETE old ctx-* skills"
fi
echo

if ! $DRY_RUN; then
    mkdir -p "$RULES_DIR"
fi

converted=0
skipped=0
deleted=0

for skill_dir in "${legacy_dirs[@]}"; do
    skill_dir="${skill_dir%/}"
    name="$(basename "$skill_dir")"          # e.g. ctx-project
    rule_name="${name#ctx-}.md"              # e.g. project.md
    src="$skill_dir/SKILL.md"
    dst="$RULES_DIR/$rule_name"

    if [[ ! -f "$src" ]]; then
        echo "skip    $name (no SKILL.md inside)"
        skipped=$((skipped + 1))
        continue
    fi

    if [[ -f "$dst" ]]; then
        echo "skip    $name (destination $rule_name already exists)"
        skipped=$((skipped + 1))
        continue
    fi

    # Strip leading YAML frontmatter block (between first pair of --- lines)
    content=$(awk '
        BEGIN { in_fm=0; fm_done=0 }
        NR==1 && /^---[[:space:]]*$/ { in_fm=1; next }
        in_fm && /^---[[:space:]]*$/ { in_fm=0; fm_done=1; next }
        in_fm { next }
        { print }
    ' "$src")

    # Drop any leading blank lines so the file starts with real content
    content=$(printf '%s\n' "$content" | awk 'NF {found=1} found {print}')

    if $DRY_RUN; then
        echo "would   create $dst  (from $name)"
    else
        printf '%s\n' "$content" > "$dst"
        echo "create  $dst  (from $name)"
    fi
    converted=$((converted + 1))

    if ! $KEEP_OLD; then
        if $DRY_RUN; then
            echo "would   remove $skill_dir"
        else
            rm -rf "$skill_dir"
            echo "remove  $skill_dir"
        fi
        deleted=$((deleted + 1))

        # Defensive: also clean any .codex/skills/ctx-* symlink pointing at the removed dir
        codex_link="$CODEX_SKILLS_DIR/$name"
        if [[ -L "$codex_link" ]]; then
            if $DRY_RUN; then
                echo "would   remove orphan symlink $codex_link"
            else
                rm "$codex_link"
                echo "remove  orphan symlink $codex_link"
            fi
        fi
    fi
done

echo
echo "Converted: $converted"
echo "Skipped:   $skipped"
if ! $KEEP_OLD; then
    echo "Removed:   $deleted legacy ctx-* skill dir(s)"
fi

if [[ $converted -gt 0 && ! $DRY_RUN ]]; then
    echo
    echo "Next step: re-run link-codex-skills.sh to refresh .codex/rules/ symlinks:"
    echo "  bash .claude/mosk/scripts/link-codex-skills.sh"
fi
