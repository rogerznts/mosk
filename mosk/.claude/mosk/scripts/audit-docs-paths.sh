#!/usr/bin/env bash
#
# audit-docs-paths.sh — verify that MOSK tasks/templates declare outputs only
# under the canonical docs/ domains, and that referenced config keys and
# template files actually exist.
#
# Exit codes: 0 = clean, 1 = violations, 2 = usage error.

set -e

QUIET=false
for arg in "$@"; do
    case "$arg" in
        --quiet) QUIET=true ;;
        --help|-h)
            cat <<'EOF'
Usage: audit-docs-paths.sh [--quiet] [--help]

Runs five checks against the MOSK toolkit:

  R1  Output paths declared in prose ("Save to:", "save it as", etc.)
      must live under docs/<canonical-domain>/.
  R2  Every templates/*.yaml `filename:` must point under docs/<canonical>.
  R3  Every tasks/*.md `docOutputLocation:` must point under docs/<canonical>.
  R4  Every <domain>.<key> reference in tasks must exist in core-config.yaml.
  R5  Every templates/*-tmpl.{yaml,md} referenced by a task must exist.

Canonical docs/ domains: discovery, prd, architecture, ui, qa, specs.
Whitelisted top-level files: docs/index.md, docs/constitution.md.

OPTIONS
  --quiet     Print nothing on success; only emit violations on failure.
  --help, -h  Show this help.
EOF
            exit 0
            ;;
        *) echo "ERROR: unknown option '$arg'. Use --help." >&2; exit 2 ;;
    esac
done

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOSK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
TASKS_DIR="$MOSK_ROOT/tasks"
TEMPLATES_DIR="$MOSK_ROOT/templates"
CONFIG_FILE="$MOSK_ROOT/core-config.yaml"

CANONICAL_DOMAIN_RE='docs/(index\.md|constitution\.md|(discovery|prd|architecture|ui|qa|specs)/)'

VIOLATIONS=()
add() { VIOLATIONS+=("$1"); }

# ---------------- R1: output paths in task prose ----------------
# Grep for phrases that introduce an output path, then flag any literal
# docs/<file>.md that isn't under a canonical domain.
check_R1() {
    local pattern='(\*\*Save to:\*\*|Save to:|Save it as|save it as|Tell user to save it as|Create the document as|Write to:|Output to:|Save the populated document to)[[:space:]]*`?(docs/[a-zA-Z0-9./_-]+)`?'
    while IFS= read -r line; do
        local file lineno path
        file=$(echo "$line" | cut -d: -f1)
        lineno=$(echo "$line" | cut -d: -f2)
        path=$(echo "$line" | grep -oE 'docs/[a-zA-Z0-9./_-]+\.md' | head -1)
        [[ -z "$path" ]] && continue
        if ! [[ "$path" =~ ^${CANONICAL_DOMAIN_RE} ]]; then
            add "${file#$MOSK_ROOT/}:${lineno} :: R1 :: output path '$path' is not under a canonical docs/ domain"
        fi
    done < <(grep -rnEi "$pattern" "$TASKS_DIR" 2>/dev/null || true)
}

# ---------------- R2: template filename: ----------------
check_R2() {
    while IFS= read -r line; do
        local file lineno path
        file=$(echo "$line" | cut -d: -f1)
        lineno=$(echo "$line" | cut -d: -f2)
        path=$(echo "$line" | sed -E 's/^[^:]+:[0-9]+:[[:space:]]*filename:[[:space:]]*//' | tr -d "'\"" | xargs)
        [[ -z "$path" ]] && continue
        if [[ "$path" != docs/* ]]; then
            add "${file#$MOSK_ROOT/}:${lineno} :: R2 :: template filename '$path' is not under docs/"
        elif ! [[ "$path" =~ ^${CANONICAL_DOMAIN_RE} ]]; then
            add "${file#$MOSK_ROOT/}:${lineno} :: R2 :: template filename '$path' is not under a canonical domain"
        fi
    done < <(grep -rnE '^[[:space:]]*filename:[[:space:]]*docs/' "$TEMPLATES_DIR" 2>/dev/null || true)
}

# ---------------- R3: task docOutputLocation: ----------------
check_R3() {
    while IFS= read -r line; do
        local file lineno path
        file=$(echo "$line" | cut -d: -f1)
        lineno=$(echo "$line" | cut -d: -f2)
        path=$(echo "$line" | sed -E 's/^[^:]+:[0-9]+:[[:space:]]*docOutputLocation:[[:space:]]*//' | tr -d "'\"" | xargs)
        [[ -z "$path" ]] && continue
        if [[ "$path" != docs/* ]]; then
            add "${file#$MOSK_ROOT/}:${lineno} :: R3 :: docOutputLocation '$path' is not under docs/"
        elif ! [[ "$path" =~ ^${CANONICAL_DOMAIN_RE} ]]; then
            add "${file#$MOSK_ROOT/}:${lineno} :: R3 :: docOutputLocation '$path' is not under a canonical domain"
        fi
    done < <(grep -rnE '^[[:space:]]*docOutputLocation:' "$TASKS_DIR" 2>/dev/null || true)
}

# ---------------- R4: <domain>.<key> exists in core-config.yaml ----------------
# Only flag refs that look like config keys: followed by '/' (path-like)
# or wrapped in backticks. Skip file-extension leaves (md, yaml, js, ...).
check_R4() {
    [[ -f "$CONFIG_FILE" ]] || { add "core-config.yaml:0 :: R4 :: file not found at $CONFIG_FILE"; return; }
    local config_keys
    config_keys=$(python3 - "$CONFIG_FILE" <<'PY'
import sys, yaml
with open(sys.argv[1]) as f:
    data = yaml.safe_load(f) or {}
pairs = []
for k, v in data.items():
    if isinstance(v, dict):
        for sub in v:
            pairs.append(f"{k}.{sub}")
    else:
        pairs.append(k)
print("\n".join(pairs))
PY
    )
    local known_domains
    known_domains=$(echo "$config_keys" | awk -F. '{print $1}' | sort -u | grep -v '^$' | tr '\n' '|' | sed 's/|$//')
    [[ -z "$known_domains" ]] && return
    local ext_blacklist='^(md|js|jsx|ts|tsx|py|sh|yaml|yml|json|html|css|xml|csv|txt|tmpl|md#section)$'
    while IFS= read -r line; do
        local file lineno
        file=$(echo "$line" | cut -d: -f1)
        lineno=$(echo "$line" | cut -d: -f2)
        # Match <domain>.<key> only when followed by '/' or wrapped in backticks
        local matches
        matches=$(echo "$line" | grep -oE "\`(${known_domains})\.[a-zA-Z][a-zA-Z0-9_]*\`|(${known_domains})\.[a-zA-Z][a-zA-Z0-9_]*/" || true)
        [[ -z "$matches" ]] && continue
        for raw in $matches; do
            # Strip backticks and trailing slash, isolate <domain>.<key>
            local clean
            clean=$(echo "$raw" | tr -d '`' | sed 's|/$||')
            local leaf="${clean#*.}"
            if [[ "$leaf" =~ $ext_blacklist ]]; then continue; fi
            if ! echo "$config_keys" | grep -qx "$clean"; then
                add "${file#$MOSK_ROOT/}:${lineno} :: R4 :: config key '$clean' is not defined in core-config.yaml"
            fi
        done
    done < <(grep -rnE "\`(${known_domains})\.[a-zA-Z]|(${known_domains})\.[a-zA-Z][a-zA-Z0-9_]*/" "$TASKS_DIR" 2>/dev/null || true)
}

# ---------------- R5: templates referenced by tasks exist ----------------
check_R5() {
    while IFS= read -r line; do
        local file lineno tmpl_path abs_path
        file=$(echo "$line" | cut -d: -f1)
        lineno=$(echo "$line" | cut -d: -f2)
        tmpl_path=$(echo "$line" | grep -oE '\.claude/mosk/templates/[a-zA-Z0-9_/-]+\.(yaml|md)' | head -1)
        [[ -z "$tmpl_path" ]] && continue
        # Resolve relative to install root: scripts dir is .../.claude/mosk/scripts
        abs_path="$MOSK_ROOT/${tmpl_path#.claude/mosk/}"
        if [[ ! -f "$abs_path" ]]; then
            add "${file#$MOSK_ROOT/}:${lineno} :: R5 :: referenced template '$tmpl_path' does not exist"
        fi
    done < <(grep -rnE '\.claude/mosk/templates/[a-zA-Z0-9_/-]+\.(yaml|md)' "$TASKS_DIR" 2>/dev/null || true)
}

check_R1
check_R2
check_R3
check_R4
check_R5

if [[ ${#VIOLATIONS[@]} -eq 0 ]]; then
    $QUIET || echo "audit-docs-paths: clean ✓ (R1..R5 all pass)"
    exit 0
fi

echo "audit-docs-paths: ${#VIOLATIONS[@]} violation(s)"
printf '  %s\n' "${VIOLATIONS[@]}"
exit 1
