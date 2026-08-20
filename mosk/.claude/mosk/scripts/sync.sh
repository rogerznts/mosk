#!/usr/bin/env bash
# sync.sh — materializa os artefatos derivados do MOSK.
#
# Funde `sync-agents-skills.sh` e `link-codex-skills.sh`. Ambos fazem a mesma
# coisa — gerar arquivo a partir de uma fonte — e compartilhavam resolução de
# caminho, contadores e o extrator de `description`.
#
# Caso 2 da lista fechada do ADR-0021: geração determinística de derivados em
# massa. Não é regra de pipeline; é materialização.
#
# FONTE ÚNICA (ADR-0015): `.claude/agents/mosk-<n>.md` é a definição; a skill
# em `.claude/skills/mosk-<n>/SKILL.md` é o wrapper gerado. Uma direção só.
# A antiga `skills-to-agents` foi removida: depois da inversão da spec 011 ela
# sobrescreveria a definição completa do agente com um ponteiro de três linhas.
#
# Usage:
#   sync.sh [skills|codex|all] [--dry-run] [--clean] [--force] [--help]
#
#     skills   agentes -> wrappers de skill (default junto de `all`)
#     codex    symlinks em .codex/ + AGENTS.md
#     all      os dois, nesta ordem (default)
#
# `--force` recria symlinks que apontam para outro lugar (só afeta `codex`).

set -e

MODE="all"; DRY_RUN=false; CLEAN=false; FORCE=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        skills|codex|all) MODE="$1" ;;
        agents-to-skills|both) MODE="skills" ;;   # nomes antigos
        skills-to-agents)
            echo "Erro: 'skills-to-agents' foi removido (ADR-0015)." >&2
            echo "      O agente e a fonte; a skill e o wrapper gerado." >&2
            exit 2 ;;
        --dry-run) DRY_RUN=true ;;
        --clean) CLEAN=true ;;
        --force) FORCE=true ;;
        --help|-h) sed -n '2,26p' "$0" | sed 's/^# \?//'; exit 0 ;;
        *) echo "opcao desconhecida: $1" >&2; exit 2 ;;
    esac
    shift
done

created=0; updated=0; kept=0; removed=0

# --- Resolve paths relative to the install root ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
# FONTE ÚNICA desde a spec 011 (ADR-0015): o CC agent. A camada intermediária
# `.claude/mosk/agents/` deixou de existir — o conteúdo migrou para cá, e o
# script deixou de ser conversão entre duas fontes concorrentes para ser
# materialização de uma só: agente → skill, numa direção.
CC_AGENTS_DIR="$INSTALL_ROOT/.claude/agents"
SKILLS_DIR="$INSTALL_ROOT/.claude/skills"

# Instalação anterior à 011 ainda tem a fonte antiga no disco. Avisamos em vez de
# ignorar: skills apontando para um caminho que sumiu falhariam em silêncio.
LEGACY_AGENTS_DIR="$INSTALL_ROOT/.claude/mosk/agents"
if [[ -d "$LEGACY_AGENTS_DIR" ]]; then
    echo "NOTE: $LEGACY_AGENTS_DIR ainda existe (layout pré-spec-011)." >&2
    echo "      A fonte agora é $CC_AGENTS_DIR. Após conferir que os agentes" >&2
    echo "      migraram, remova o diretório antigo." >&2
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

# Extract the canonical routing description declared by an agent .md:
#
#   <!-- skill-description: text with the routing triggers -->
#
# This is the SOURCE OF TRUTH for a skill's `description:`. It exists because
# the description is a *routing* string (pt-BR, trigger-rich, read by the host
# to decide when to load the skill) while ## Mission is *persona prose* (in
# English, multi-line, read by the model once loaded). Deriving one from the
# other truncated every curated description the moment this script ran.
# Must be a single physical line and must not contain double quotes.
extract_skill_description() {
    local file="$1"
    [[ -f "$file" ]] || return 1
    sed -n 's/^<!-- *skill-description: *\(.*[^ ]\) *-->[[:space:]]*$/\1/p' "$file" | head -1
}

# Fallback for agents that predate `skill-description`: the Mission's first line.
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

    if [[ ! -d "$CC_AGENTS_DIR" ]]; then
        echo "WARN: $CC_AGENTS_DIR not found, skipping."
        return
    fi

    for agent_file in "$CC_AGENTS_DIR"/mosk-*.md; do
        [[ -f "$agent_file" ]] || continue
        local skill_name name
        skill_name="$(basename "$agent_file" .md)"   # mosk-<n>
        name="${skill_name#mosk-}"                    # <n>
        local skill_file="$SKILLS_DIR/$skill_name/SKILL.md"

        # Resolve description, in order:
        #   1. front-matter `description:` do CC agent    — canônico desde a 011
        #   2. `skill-description` legada no corpo        — agente ainda não migrado
        #   3. wrapper existente                          — preserva texto curado
        #   4. primeira linha da Mission                  — agente sem o campo
        #   5. fallback genérico
        # (3) fica acima de (4) de propósito: uma description já no lugar é texto
        # curado, e substituí-la em silêncio por prosa é regressão.
        local desc=""
        desc="$(extract_description "$agent_file" 2>/dev/null)" || true
        if [[ -z "$desc" ]]; then
            desc="$(extract_skill_description "$agent_file" 2>/dev/null)" || true
        fi
        if [[ -z "$desc" ]]; then
            desc="$(extract_description "$skill_file" 2>/dev/null)" || true
        fi
        if [[ -z "$desc" ]]; then
            desc="$(extract_mission "$agent_file" 2>/dev/null)" || true
        fi
        if [[ -z "$desc" ]]; then
            desc="MOSK $name agent."
        fi
        if [[ "$desc" == *'"'* ]]; then
            echo "WARN: description of $skill_name contains a double quote — it would break the YAML front-matter; stripping." >&2
            desc="${desc//\"/}"
        fi

        # An existing wrapper is edited IN PLACE: only the `description:` line is
        # refreshed. Wrappers carry authored content the generator knows nothing
        # about — extra front-matter keys (`argument-hint:`) and hand-written
        # bodies — and regenerating from the boilerplate silently deleted them.
        if [[ -f "$skill_file" ]]; then
            local current_desc
            current_desc="$(extract_description "$skill_file" 2>/dev/null)" || true
            if [[ "$current_desc" == "$desc" ]]; then
                echo "keep    $skill_name/SKILL.md"
                kept=$((kept + 1))
                continue
            fi
            if [[ "$DRY_RUN" == "true" ]]; then
                echo "dry-run  would refresh description of $skill_file"
            else
                local tmp="$skill_file.tmp.$$"
                awk -v d="$desc" '
                    !done && /^description:/ { print "description: \"" d "\""; done = 1; next }
                    { print }
                ' "$skill_file" > "$tmp" && mv "$tmp" "$skill_file"
            fi
            echo "update  $skill_name/SKILL.md (description)"
            updated=$((updated + 1))
            continue
        fi

        local content
        content="$(cat <<SKILL_EOF
---
name: $skill_name
description: "$desc"
---

CRITICAL: Read and fully execute the agent definition at \`.claude/agents/$skill_name.md\`.
That file is the single source of truth — it contains the full persona, commands, dependencies,
and activation instructions. Follow ALL instructions defined there exactly.
SKILL_EOF
)"

        write_file "$skill_file" "$content"
        echo "create  $skill_name/SKILL.md"
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
    if [[ -d "$CC_AGENTS_DIR" ]]; then
        for f in "$CC_AGENTS_DIR"/mosk-*.md; do
            [[ -f "$f" ]] || continue
            roster+=("$(basename "$f" .md | sed 's/^mosk-//')")
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
        mosk-suggestion mosk-update mosk-write-skill
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


# --- codex: symlinks e AGENTS.md -------------------------------------------
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


# Caminhos do modo codex. Vinham do header do link-codex-skills.sh; sem eles,
# `ln` recebia caminho vazio e tentava escrever na raiz do sistema.
AGENTS_DIR="$CC_AGENTS_DIR"
RULES_DIR="$INSTALL_ROOT/.claude/rules"
TARGET_DIR="${CODEX_SKILLS_DIR:-$INSTALL_ROOT/.codex/skills}"
TARGET_RULES_DIR="${CODEX_RULES_DIR:-$INSTALL_ROOT/.codex/rules}"
skipped=0

link_codex() {
    mkdir -p "$TARGET_DIR"
# --- Phase 0: Clean orphan entries in .codex/skills ---
# Legacy ctx-* skills may have been removed (e.g., by migrate-ctx-skills-to-rules.sh);
# agent-wrapped skills leave a DIRECTORY containing a SKILL.md symlink whose target
# (a CC agent or a skill's SKILL.md) may no longer exist. Remove both shapes:
#   1) a top-level symlink entry whose target is gone;
#   2) a directory entry whose SKILL.md symlink dangles (agent wrappers — this is
#      the case Phase 0 previously missed, leaving dead codex skills behind).
if [[ -d "$TARGET_DIR" ]]; then
    for entry in "$TARGET_DIR"/*; do
        if [[ -L "$entry" && ! -e "$entry" ]]; then
            rm "$entry"
            echo "remove  orphan symlink $(basename "$entry")"
        elif [[ -d "$entry" && -L "$entry/SKILL.md" && ! -e "$entry/SKILL.md" ]]; then
            rm -rf "$entry"
            echo "remove  orphan skill dir (dangling SKILL.md) $(basename "$entry")"
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
            # NAO tentar tirar as aspas dentro do sed: `\(.*\)` e guloso, engole a
            # aspa final e o `"\{0,1\}$` casa vazio — era assim que quase toda
            # entrada do AGENTS.md terminava com um `"` sobrando.
            desc=$(sed -n 's/^description: *//p' "$skill_file" 2>/dev/null | head -1)
            desc="${desc#\"}"
            desc="${desc%\"}"
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
}

# --- dispatch ---------------------------------------------------------------
case "$MODE" in
    skills) agents_to_skills ;;
    codex)  link_codex ;;
    all)    agents_to_skills; link_codex ;;
esac

[[ "$CLEAN" == "true" ]] && clean_orphans

echo "Created: $created"
echo "Updated: $updated"
echo "Kept:    $kept"
echo "Removed: $removed"
