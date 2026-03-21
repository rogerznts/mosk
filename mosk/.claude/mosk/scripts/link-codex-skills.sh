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

Create symlinks from the project's .claude skills and agents into ./.codex/skills.

Claude Code skills (directories) are linked directly.
Claude Code agents (.md files) are wrapped into a Codex-compatible skill directory
with a SKILL.md symlink pointing to the agent file.

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
SKILLS_DIR="$INSTALL_ROOT/.claude/skills"
AGENTS_DIR="$INSTALL_ROOT/.claude/agents"
TARGET_DIR="${CODEX_SKILLS_DIR:-$INSTALL_ROOT/.codex/skills}"

mkdir -p "$TARGET_DIR"

created=0
updated=0
kept=0
skipped=0

# --- Helper: link a skill directory (symlink the whole dir) ---
link_skill_dir() {
    local source_path="$1"
    local name="$2"
    local link_path="$TARGET_DIR/$name"

    if [[ -L "$link_path" ]]; then
        current_target="$(readlink "$link_path")"

        if [[ "$current_target" == "$source_path" ]]; then
            echo "keep    $name (skill)"
            kept=$((kept + 1))
            return
        fi

        if [[ "$FORCE" != "true" ]]; then
            echo "skip    $name (symlink already exists: $current_target)"
            skipped=$((skipped + 1))
            return
        fi

        rm "$link_path"
        ln -s "$source_path" "$link_path"
        echo "update  $name -> $source_path"
        updated=$((updated + 1))
        return
    fi

    if [[ -e "$link_path" ]]; then
        echo "skip    $name (destination exists and is not a symlink)"
        skipped=$((skipped + 1))
        return
    fi

    ln -s "$source_path" "$link_path"
    echo "create  $name -> $source_path"
    created=$((created + 1))
}

# --- Helper: link an agent file as a Codex skill ---
# Creates .codex/skills/<name>/SKILL.md -> .claude/agents/<name>.md
link_agent_file() {
    local agent_file="$1"
    local name="$2"
    local skill_dir="$TARGET_DIR/$name"
    local link_path="$skill_dir/SKILL.md"

    # If a skill directory symlink already covers this name, skip the agent
    if [[ -L "$skill_dir" ]]; then
        return
    fi

    mkdir -p "$skill_dir"

    if [[ -L "$link_path" ]]; then
        current_target="$(readlink "$link_path")"

        if [[ "$current_target" == "$agent_file" ]]; then
            echo "keep    $name (agent)"
            kept=$((kept + 1))
            return
        fi

        if [[ "$FORCE" != "true" ]]; then
            echo "skip    $name (SKILL.md symlink already exists: $current_target)"
            skipped=$((skipped + 1))
            return
        fi

        rm "$link_path"
        ln -s "$agent_file" "$link_path"
        echo "update  $name/SKILL.md -> $agent_file"
        updated=$((updated + 1))
        return
    fi

    if [[ -e "$link_path" ]]; then
        echo "skip    $name (SKILL.md exists and is not a symlink)"
        skipped=$((skipped + 1))
        return
    fi

    ln -s "$agent_file" "$link_path"
    echo "create  $name/SKILL.md -> $agent_file"
    created=$((created + 1))
}

# --- Phase 1: Link skill directories ---
if [[ -d "$SKILLS_DIR" ]]; then
    for skill_dir in "$SKILLS_DIR"/*; do
        [[ -d "$skill_dir" ]] || continue
        skill_name="$(basename "$skill_dir")"
        link_skill_dir "$skill_dir" "$skill_name"
    done
fi

# --- Phase 2: Link agent files as Codex skills ---
if [[ -d "$AGENTS_DIR" ]]; then
    for agent_file in "$AGENTS_DIR"/*.md; do
        [[ -f "$agent_file" ]] || continue
        agent_name="$(basename "$agent_file" .md)"
        link_agent_file "$agent_file" "$agent_name"
    done
fi

# --- Summary ---
echo
sources=()
[[ -d "$SKILLS_DIR" ]] && sources+=("$SKILLS_DIR")
[[ -d "$AGENTS_DIR" ]] && sources+=("$AGENTS_DIR")
echo "Sources: ${sources[*]}"
echo "Target:  $TARGET_DIR"
echo "Created: $created"
echo "Updated: $updated"
echo "Kept:    $kept"
echo "Skipped: $skipped"
