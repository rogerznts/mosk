#!/usr/bin/env bash

set -e

FORCE=false

for arg in "$@"; do
    case "$arg" in
        --force)
            FORCE=true
            ;;
        --help|-h)
            cat <<'EOF'
Usage: link-codex-skills.sh [--force]

Create symlinks from the project's .claude skills into ~/.codex/skills.

OPTIONS:
  --force     Recreate existing symlinks, even if they point elsewhere
  --help, -h  Show this help message

ENVIRONMENT:
  CODEX_SKILLS_DIR  Override the target skills directory
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
SOURCE_DIR="$INSTALL_ROOT/.claude/skills"
TARGET_DIR="${CODEX_SKILLS_DIR:-$HOME/.codex/skills}"

if [[ ! -d "$SOURCE_DIR" ]]; then
    echo "ERROR: Skills source directory not found: $SOURCE_DIR" >&2
    exit 1
fi

mkdir -p "$TARGET_DIR"

created=0
updated=0
kept=0
skipped=0

for skill_dir in "$SOURCE_DIR"/*; do
    [[ -d "$skill_dir" ]] || continue

    skill_name="$(basename "$skill_dir")"
    link_path="$TARGET_DIR/$skill_name"

    if [[ -L "$link_path" ]]; then
        current_target="$(readlink "$link_path")"

        if [[ "$current_target" == "$skill_dir" ]]; then
            echo "keep    $skill_name"
            kept=$((kept + 1))
            continue
        fi

        if [[ "$FORCE" != "true" ]]; then
            echo "skip    $skill_name (symlink already exists: $current_target)"
            skipped=$((skipped + 1))
            continue
        fi

        rm "$link_path"
        ln -s "$skill_dir" "$link_path"
        echo "update  $skill_name -> $skill_dir"
        updated=$((updated + 1))
        continue
    fi

    if [[ -e "$link_path" ]]; then
        echo "skip    $skill_name (destination exists and is not a symlink)"
        skipped=$((skipped + 1))
        continue
    fi

    ln -s "$skill_dir" "$link_path"
    echo "create  $skill_name -> $skill_dir"
    created=$((created + 1))
done

echo
echo "Source: $SOURCE_DIR"
echo "Target: $TARGET_DIR"
echo "Created: $created"
echo "Updated: $updated"
echo "Kept: $kept"
echo "Skipped: $skipped"
