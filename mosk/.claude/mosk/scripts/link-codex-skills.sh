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

Create symlinks from the project's .claude skills, agents, and rules into .codex/.

Claude Code skills (directories) are linked into .codex/skills/.
Claude Code agents (.md files) are wrapped into a Codex-compatible skill directory
with a SKILL.md symlink pointing to the agent file.
Project rules (.claude/rules/*.md) are linked into .codex/rules/ so Codex CLI
can read them alongside AGENTS.md.

OPTIONS:
  --force     Recreate existing symlinks, even if they point elsewhere
  --help, -h  Show this help message

ENVIRONMENT:
  CODEX_SKILLS_DIR  Override the target skills directory
  CODEX_RULES_DIR   Override the target rules directory
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
RULES_DIR="$INSTALL_ROOT/.claude/rules"
TARGET_DIR="${CODEX_SKILLS_DIR:-$INSTALL_ROOT/.codex/skills}"
TARGET_RULES_DIR="${CODEX_RULES_DIR:-$INSTALL_ROOT/.codex/rules}"

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

# --- Phase 0: Clean orphan symlinks in .codex/skills ---
# Legacy ctx-* skills may have been removed (e.g., by migrate-ctx-skills-to-rules.sh).
# Any symlink in TARGET_DIR whose target no longer exists is removed.
if [[ -d "$TARGET_DIR" ]]; then
    for entry in "$TARGET_DIR"/*; do
        if [[ -L "$entry" && ! -e "$entry" ]]; then
            rm "$entry"
            echo "remove  orphan symlink $(basename "$entry")"
        fi
    done
fi

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

# --- Phase 2b: Link project rules into .codex/rules ---
# Rules in .claude/rules/*.md are linked 1:1 into TARGET_RULES_DIR so that
# Codex CLI (which reads AGENTS.md) can follow the reference and load them.
if [[ -d "$RULES_DIR" ]]; then
    mkdir -p "$TARGET_RULES_DIR"

    # Clean orphan rule symlinks first
    for rlink in "$TARGET_RULES_DIR"/*; do
        if [[ -L "$rlink" && ! -e "$rlink" ]]; then
            rm "$rlink"
            echo "remove  orphan rule symlink $(basename "$rlink")"
        fi
    done

    for rule_file in "$RULES_DIR"/*.md; do
        [[ -f "$rule_file" ]] || continue
        rule_basename="$(basename "$rule_file")"
        rule_link="$TARGET_RULES_DIR/$rule_basename"

        if [[ -L "$rule_link" ]]; then
            current_target="$(readlink "$rule_link")"
            if [[ "$current_target" == "$rule_file" ]]; then
                echo "keep    rules/$rule_basename"
                kept=$((kept + 1))
                continue
            fi
            if [[ "$FORCE" != "true" ]]; then
                echo "skip    rules/$rule_basename (symlink already exists: $current_target)"
                skipped=$((skipped + 1))
                continue
            fi
            rm "$rule_link"
            ln -s "$rule_file" "$rule_link"
            echo "update  rules/$rule_basename -> $rule_file"
            updated=$((updated + 1))
            continue
        fi

        if [[ -e "$rule_link" ]]; then
            echo "skip    rules/$rule_basename (destination exists and is not a symlink)"
            skipped=$((skipped + 1))
            continue
        fi

        ln -s "$rule_file" "$rule_link"
        echo "create  rules/$rule_basename -> $rule_file"
        created=$((created + 1))
    done
fi

# --- Phase 3: Generate AGENTS.md with reference to CLAUDE.md ---
AGENTS_MD="$INSTALL_ROOT/AGENTS.md"

{
    cat <<'HEADER'
# AGENTS.md

This file is auto-generated by `link-codex-skills.sh`.
It provides Codex CLI (and compatible agents) with project context.

## Project Instructions

See [CLAUDE.md](./CLAUDE.md) for the full project instructions, conventions, and context.
All rules defined there apply to every agent operating in this repository.

## Available Skills

The following skills are linked in `.codex/skills/`:

HEADER

    for entry in "$TARGET_DIR"/*; do
        [[ -d "$entry" || -L "$entry" ]] || continue
        entry_name="$(basename "$entry")"
        skill_file="$entry/SKILL.md"
        desc=""
        if [[ -f "$skill_file" ]]; then
            desc=$(sed -n 's/^description: *"\{0,1\}\(.*\)"\{0,1\}$/\1/p' "$skill_file" 2>/dev/null | head -1)
        fi
        if [[ -n "$desc" ]]; then
            echo "- **$entry_name**: $desc"
        else
            echo "- **$entry_name**"
        fi
    done

    cat <<'FOOTER'

## Project Rules

Project-wide rules are symlinked into `.codex/rules/` (source: `.claude/rules/*.md`).
Read every file there before executing any request — they define the project's stack,
conventions, and constraints. MOSK agents running through Claude Code read
`.claude/rules/*.md` directly; Codex CLI should follow the `.codex/rules/` symlinks.

Run `/mosk-boot` to generate project rules if they don't exist yet. To migrate a
project from legacy `ctx-*` context skills into the new rule layout, run:

```bash
bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh
```
FOOTER
} > "$AGENTS_MD"

echo
echo "Generated: AGENTS.md (with reference to CLAUDE.md)"

# --- Summary ---
echo
sources=()
[[ -d "$SKILLS_DIR" ]] && sources+=("$SKILLS_DIR")
[[ -d "$AGENTS_DIR" ]] && sources+=("$AGENTS_DIR")
[[ -d "$RULES_DIR"  ]] && sources+=("$RULES_DIR")
echo "Sources:      ${sources[*]}"
echo "Target:       $TARGET_DIR"
[[ -d "$RULES_DIR" ]] && echo "Target rules: $TARGET_RULES_DIR"
echo "Created: $created"
echo "Updated: $updated"
echo "Kept:    $kept"
echo "Skipped: $skipped"
