#!/usr/bin/env bash

set -e

# sync-agents-skills.sh
#
# Synchronizes MOSK agents, Claude Code agents, and skill wrappers.
#
# Directions:
#   agents-to-skills  — generate .claude/skills/mosk-NAME/SKILL.md from .claude/mosk/agents/NAME.md
#   skills-to-agents  — generate .claude/agents/mosk-NAME.md from .claude/skills/mosk-NAME/SKILL.md
#   both              — run both directions (default)
#
# Usage: sync-agents-skills.sh [agents-to-skills|skills-to-agents|both] [--dry-run] [--clean]

DIRECTION="${1:-both}"
DRY_RUN=false
CLEAN=false

for arg in "$@"; do
    case "$arg" in
        --dry-run)  DRY_RUN=true ;;
        --clean)    CLEAN=true ;;
        --help|-h)
            cat <<'EOF'
Usage: sync-agents-skills.sh [DIRECTION] [--dry-run] [--clean]

DIRECTION:
  agents-to-skills   Generate skill wrappers from agent definitions
  skills-to-agents   Generate Claude Code agents from skill definitions
  both               Run both directions (default)

OPTIONS:
  --dry-run   Show what would be done without writing files
  --clean     Remove orphan skills and CC agents that have no corresponding source agent
  --help, -h  Show this help message

STRUCTURE:
  Source agents:       .claude/mosk/agents/NAME.md
  Skill wrappers:      .claude/skills/mosk-NAME/SKILL.md
  Claude Code agents:  .claude/agents/mosk-NAME.md
EOF
            exit 0
            ;;
        agents-to-skills|skills-to-agents|both) ;;
        *)
            echo "ERROR: Unknown option '$arg'. Use --help for usage." >&2
            exit 1
            ;;
    esac
done

# --- Resolve paths relative to the install root ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
MOSK_AGENTS_DIR="$INSTALL_ROOT/.claude/mosk/agents"
SKILLS_DIR="$INSTALL_ROOT/.claude/skills"
CC_AGENTS_DIR="$INSTALL_ROOT/.claude/agents"

# Dev repo fallback: if CC_AGENTS_DIR doesn't exist, try parent (root .claude/agents/)
if [[ ! -d "$CC_AGENTS_DIR" ]]; then
    _parent_agents="$(cd "$INSTALL_ROOT/.." && pwd)/.claude/agents"
    if [[ -d "$_parent_agents" ]]; then
        CC_AGENTS_DIR="$_parent_agents"
    fi
fi

# --- Warn about legacy ctx-* context skills ---
# Since MOSK now stores project context in .claude/rules/*.md, any remaining
# ctx-* skill directories are stale. Warn the user (non-blocking).
if [[ -d "$SKILLS_DIR" ]]; then
    shopt -s nullglob
    _legacy_ctx=("$SKILLS_DIR"/ctx-*/)
    shopt -u nullglob
    if [[ ${#_legacy_ctx[@]} -gt 0 ]]; then
        echo "NOTE: found ${#_legacy_ctx[@]} legacy ctx-* skill(s) in $SKILLS_DIR"
        echo "      Project context now lives in .claude/rules/*.md."
        echo "      Migrate with: bash .claude/mosk/scripts/migrate-ctx-skills-to-rules.sh"
        echo
    fi
fi

created=0
updated=0
kept=0
removed=0

# --- Helpers ---

# Extract description from a file's YAML frontmatter (strips surrounding quotes)
extract_description() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    local raw
    raw="$(sed -n '/^---$/,/^---$/{ s/^description: *//p; }' "$file" | head -1)"
    # Strip surrounding quotes if present
    raw="${raw#\"}"
    raw="${raw%\"}"
    echo "$raw"
}

# Extract the Mission section's first sentence from an agent .md
extract_mission() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    sed -n '/^## Mission$/,/^##/{/^## Mission$/d; /^##/d; /^$/d; p;}' "$file" | head -1
}

# Write a file (respects --dry-run)
write_file() {
    local path="$1"
    local content="$2"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "dry-run  would write $path"
        return
    fi

    mkdir -p "$(dirname "$path")"
    printf '%s\n' "$content" > "$path"
}

# --- agents-to-skills: generate SKILL.md wrappers ---
agents_to_skills() {
    echo "=== agents → skills ==="
    echo

    if [[ ! -d "$MOSK_AGENTS_DIR" ]]; then
        echo "WARN: $MOSK_AGENTS_DIR not found, skipping."
        return
    fi

    for agent_file in "$MOSK_AGENTS_DIR"/*.md; do
        [[ -f "$agent_file" ]] || continue
        local name
        name="$(basename "$agent_file" .md)"
        local skill_name="mosk-$name"
        local skill_file="$SKILLS_DIR/$skill_name/SKILL.md"

        # Resolve description: CC agent > mission from source > existing skill (fallback)
        local desc=""
        desc="$(extract_description "$CC_AGENTS_DIR/$skill_name.md" 2>/dev/null)" || true
        if [[ -z "$desc" ]]; then
            desc="$(extract_mission "$agent_file" 2>/dev/null)" || true
        fi
        if [[ -z "$desc" ]]; then
            desc="$(extract_description "$skill_file" 2>/dev/null)" || true
        fi
        if [[ -z "$desc" ]]; then
            desc="MOSK $name agent."
        fi

        local content
        content="$(cat <<SKILL_EOF
---
name: $skill_name
description: "$desc"
---

CRITICAL: Read and fully execute the agent definition at \`../../mosk/agents/$name.md\`.
That file is the single source of truth — it contains the full persona, commands, dependencies,
and activation instructions. Follow ALL instructions defined there exactly.
SKILL_EOF
)"

        # Check if skill already exists with same content
        if [[ -f "$skill_file" ]]; then
            existing="$(cat "$skill_file")"
            if [[ "$existing" == "$content" ]]; then
                echo "keep    $skill_name/SKILL.md"
                kept=$((kept + 1))
                continue
            fi
            write_file "$skill_file" "$content"
            echo "update  $skill_name/SKILL.md"
            updated=$((updated + 1))
        else
            write_file "$skill_file" "$content"
            echo "create  $skill_name/SKILL.md"
            created=$((created + 1))
        fi
    done

    echo
}

# --- skills-to-agents: generate Claude Code agent .md ---
skills_to_agents() {
    echo "=== skills → agents ==="
    echo

    if [[ ! -d "$SKILLS_DIR" ]]; then
        echo "WARN: $SKILLS_DIR not found, skipping."
        return
    fi

    mkdir -p "$CC_AGENTS_DIR"

    for skill_dir in "$SKILLS_DIR"/mosk-*/; do
        [[ -d "$skill_dir" ]] || continue
        local skill_name
        skill_name="$(basename "$skill_dir")"
        local skill_file="$skill_dir/SKILL.md"
        local agent_file="$CC_AGENTS_DIR/$skill_name.md"

        # Skip non-agent skills (boot, help)
        local base_name="${skill_name#mosk-}"
        local source_agent="$MOSK_AGENTS_DIR/$base_name.md"

        if [[ ! -f "$source_agent" ]]; then
            echo "skip    $skill_name (no source agent at mosk/agents/$base_name.md)"
            continue
        fi

        # If CC agent already exists, keep it (it may have PT-BR content)
        if [[ -f "$agent_file" ]]; then
            echo "keep    $skill_name.md (already exists)"
            kept=$((kept + 1))
            continue
        fi

        # Extract description from skill
        local desc=""
        desc="$(extract_description "$skill_file" 2>/dev/null)" || true
        if [[ -z "$desc" ]]; then
            desc="$(extract_mission "$source_agent" 2>/dev/null)" || true
        fi
        if [[ -z "$desc" ]]; then
            desc="MOSK $base_name agent."
        fi

        # Extract persona name and role from source agent's first line
        local title_line
        title_line="$(head -1 "$source_agent")"
        # e.g. "# Maria - Analyst" → persona="Maria", role="Analyst"
        local persona role
        persona="$(echo "$title_line" | sed -n 's/^# \(.*\) - .*/\1/p')"
        role="$(echo "$title_line" | sed -n 's/^# .* - \(.*\)/\1/p')"

        local content
        content="$(cat <<AGENT_EOF
---
name: $skill_name
description: "$desc"
---

# ${persona:-$base_name} - ${role:-Agent}

Read and execute the full agent definition at \`../mosk/agents/$base_name.md\`.
That file is the single source of truth for this agent's persona, tasks, and behavior.
AGENT_EOF
)"

        write_file "$agent_file" "$content"
        echo "create  $skill_name.md"
        created=$((created + 1))
    done

    echo
}

# --- clean: remove all orphan artifacts across all three layers ---
# Builds a roster from source agents, then removes anything mosk-* that isn't in the roster.
clean_orphans() {
    echo "=== clean orphans ==="
    echo

    # Build roster of valid agent base names from source agents
    local -a roster=()
    if [[ -d "$MOSK_AGENTS_DIR" ]]; then
        for f in "$MOSK_AGENTS_DIR"/*.md; do
            [[ -f "$f" ]] || continue
            roster+=("$(basename "$f" .md)")
        done
    fi

    # Helper: check if a name is in the roster
    in_roster() {
        local name="$1"
        for r in "${roster[@]}"; do
            [[ "$r" == "$name" ]] && return 0
        done
        return 1
    }

    # Allowlist: standalone skills (no backing persona) that --clean must NEVER
    # treat as orphan wrappers. Needed because the "agent definition" substring
    # test below matches legitimate skills that merely *document* wrapper
    # authoring (e.g. mosk-write-skill), which would otherwise be rm -rf'd.
    # Keep in sync when adding a standalone (non-persona) skill.
    local -a standalone_skills=(
        mosk-boot mosk-deploy mosk-handoff mosk-help
        mosk-suggestion mosk-update mosk-write-skill mosk-orq
    )
    is_standalone() {
        local name="$1"
        for s in "${standalone_skills[@]}"; do
            [[ "$s" == "$name" ]] && return 0
        done
        return 1
    }

    # Helper: remove a file or directory
    do_remove() {
        local path="$1"
        local label="$2"
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "dry-run  would remove $label"
        else
            rm -rf "$path"
            echo "remove  $label"
        fi
        removed=$((removed + 1))
    }

    # 1. Clean orphan skill wrappers (mosk-* only, skip standalone like boot/help/tea-*)
    if [[ -d "$SKILLS_DIR" ]]; then
        for skill_dir in "$SKILLS_DIR"/mosk-*/; do
            [[ -d "$skill_dir" ]] || continue
            local skill_name base_name skill_file
            skill_name="$(basename "$skill_dir")"
            base_name="${skill_name#mosk-}"
            skill_file="$skill_dir/SKILL.md"

            # Never remove an allowlisted standalone skill.
            is_standalone "$skill_name" && continue

            # Only target agent wrappers (contain "agent definition")
            if [[ -f "$skill_file" ]] && grep -q "agent definition" "$skill_file" 2>/dev/null; then
                if ! in_roster "$base_name"; then
                    do_remove "$skill_dir" "$skill_name/ (orphan skill)"
                fi
            fi
        done
    fi

    # 2. Clean orphan CC agents (mosk-* only)
    if [[ -d "$CC_AGENTS_DIR" ]]; then
        for agent_file in "$CC_AGENTS_DIR"/mosk-*.md; do
            [[ -f "$agent_file" ]] || continue
            local skill_name base_name
            skill_name="$(basename "$agent_file" .md)"
            base_name="${skill_name#mosk-}"

            if ! in_roster "$base_name"; then
                do_remove "$agent_file" "$skill_name.md (orphan CC agent)"
            fi
        done
    fi

    # 3. Also check dev repo fallback: parent .claude/agents/ and .claude/skills/
    local _parent_root
    _parent_root="$(cd "$INSTALL_ROOT/.." 2>/dev/null && pwd)" || true
    if [[ -n "$_parent_root" && "$_parent_root" != "$INSTALL_ROOT" ]]; then
        local _parent_agents_dir="$_parent_root/.claude/agents"
        local _parent_skills_dir="$_parent_root/.claude/skills"

        if [[ -d "$_parent_agents_dir" ]]; then
            for agent_file in "$_parent_agents_dir"/mosk-*.md; do
                [[ -f "$agent_file" ]] || continue
                local skill_name base_name
                skill_name="$(basename "$agent_file" .md)"
                base_name="${skill_name#mosk-}"
                if ! in_roster "$base_name"; then
                    do_remove "$agent_file" "$skill_name.md (orphan CC agent, parent)"
                fi
            done
        fi

        if [[ -d "$_parent_skills_dir" ]]; then
            for skill_dir in "$_parent_skills_dir"/mosk-*/; do
                [[ -d "$skill_dir" ]] || continue
                local skill_name base_name skill_file
                skill_name="$(basename "$skill_dir")"
                base_name="${skill_name#mosk-}"
                skill_file="$skill_dir/SKILL.md"
                is_standalone "$skill_name" && continue
                if [[ -f "$skill_file" ]] && grep -q "agent definition" "$skill_file" 2>/dev/null; then
                    if ! in_roster "$base_name"; then
                        do_remove "$skill_dir" "$skill_name/ (orphan skill, parent)"
                    fi
                fi
            done
        fi
    fi

    echo
}

# --- Run requested direction(s) ---
case "$DIRECTION" in
    agents-to-skills)
        agents_to_skills
        ;;
    skills-to-agents)
        skills_to_agents
        ;;
    both)
        agents_to_skills
        skills_to_agents
        ;;
esac

# Run clean if requested
if [[ "$CLEAN" == "true" ]]; then
    clean_orphans
fi

# --- Summary ---
echo "Created: $created"
echo "Updated: $updated"
echo "Kept:    $kept"
echo "Removed: $removed"
