#!/usr/bin/env bash
# doctor.sh — diagnóstico autocontido da instalação MOSK.
# Exit 0 = íntegro; 1 = violações; 2 = erro de uso.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MOSK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
INSTALL_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
JSON=0

usage() {
    cat <<'EOF'
doctor.sh [--json] [--help]

Verifica a integridade da instalação MOSK sem modificar arquivos:
  - sintaxe de todos os scripts Bash;
  - self-tests do toolkit;
  - referências internas entre agents/skills/tasks/templates/scripts;
  - caminhos documentais e chaves do core-config;
  - paridade agent -> skill em dry-run;
  - roster e arquivos obrigatórios.

Exit codes: 0 íntegro; 1 violação; 2 erro de uso.

Opções:
  --json     saída resumida em JSON
  --help,-h  esta ajuda
EOF
}

# Valida somente referências literais para arquivos permanentes do produto.
# Diretórios genéricos, globs e placeholders são ignorados de propósito.
validate_internal_refs() {
    local install_root="$1"
    shift
    local failed=0 scan file line ref target
    for scan in "$@"; do
        [[ -e "$scan" ]] || continue
        while IFS=: read -r file line ref; do
            [[ -n "$ref" ]] || continue
            case "$ref" in
                */|*-|*.|*NAME*|*'ctx-'*|*'<'*|*'{'*|*'*'*) continue ;;
            esac
            case "$ref" in
                .claude/*) target="$install_root/$ref" ;;
                ../*) target="$(dirname "$file")/$ref" ;;
                *) continue ;;
            esac
            if [[ ! -e "$target" ]]; then
                echo "${file#$install_root/}:$line :: REF :: '$ref' não existe"
                failed=1
            fi
        done < <(grep -rnEo '(\.claude/(agents|skills|mosk/(tasks|templates|checklists|scripts|data))|\.\./(tasks|templates|checklists|scripts|data))/[A-Za-z0-9._/-]+' "$scan" 2>/dev/null || true)
    done
    return "$failed"
}

check_bash_syntax() {
    local file failed=0
    for file in "$SCRIPT_DIR"/*.sh; do
        [[ -f "$file" ]] || continue
        if ! bash -n "$file"; then failed=1; fi
    done
    return "$failed"
}

check_selftests() {
    local file failed=0
    for file in "$SCRIPT_DIR"/selftest-*.sh; do
        [[ -f "$file" ]] || continue
        if ! bash "$file"; then failed=1; fi
    done
    return "$failed"
}

check_references() {
    local script script_name
    local scripts=()
    for script in "$SCRIPT_DIR"/*.sh; do
        script_name="$(basename "$script")"
        [[ "$script_name" == selftest-* ]] || scripts+=("$script")
    done
    validate_internal_refs "$INSTALL_ROOT" \
        "$INSTALL_ROOT/.claude/agents" \
        "$INSTALL_ROOT/.claude/skills" \
        "$MOSK_ROOT/tasks" \
        "$MOSK_ROOT/templates" \
        "$MOSK_ROOT/checklists" \
        "${scripts[@]}" \
        "$INSTALL_ROOT/.claude/README.md"
}

check_agent_skill_sync() {
    local output
    output="$(bash "$SCRIPT_DIR/sync-agents-skills.sh" agents-to-skills --dry-run 2>&1)" || {
        printf '%s\n' "$output"
        return 1
    }
    if printf '%s\n' "$output" | grep -Eq '^(create|update|dry-run[[:space:]]+would)'; then
        printf '%s\n' "$output"
        return 1
    fi
}

check_roster() {
    local agents wrappers
    agents=$(find "$INSTALL_ROOT/.claude/agents" -maxdepth 1 -type f -name 'mosk-*.md' 2>/dev/null | wc -l | tr -d ' ')
    wrappers=0
    local agent name
    for agent in "$INSTALL_ROOT/.claude/agents"/mosk-*.md; do
        [[ -f "$agent" ]] || continue
        name="$(basename "$agent" .md)"
        [[ -f "$INSTALL_ROOT/.claude/skills/$name/SKILL.md" ]] && wrappers=$((wrappers + 1))
    done
    if [[ "$agents" -ne 12 || "$wrappers" -ne "$agents" ]]; then
        echo "roster divergente: agents=$agents wrappers=$wrappers esperado=12"
        return 1
    fi
}

check_required_files() {
    local failed=0 path
    for path in \
        "$MOSK_ROOT/core-config.yaml" \
        "$MOSK_ROOT/data/output-contract.md" \
        "$MOSK_ROOT/schemas/spec-meta.schema.json" \
        "$MOSK_ROOT/schemas/qa-gate.schema.json" \
        "$SCRIPT_DIR/transition-spec-phase.sh" \
        "$SCRIPT_DIR/selftest-pipeline-state.sh" \
        "$MOSK_ROOT/templates/spec-meta-tmpl.yaml" \
        "$MOSK_ROOT/templates/qa-gate-tmpl.yaml"; do
        if [[ ! -f "$path" ]]; then
            echo "arquivo obrigatório ausente: ${path#$INSTALL_ROOT/}"
            failed=1
        fi
    done
    return "$failed"
}

CHECK_NAMES=()
FAIL_NAMES=()
DETAILS=()

run_check() {
    local name="$1"
    shift
    local tmp
    tmp="$(mktemp)"
    CHECK_NAMES+=("$name")
    if "$@" >"$tmp" 2>&1; then
        [[ "$JSON" -eq 0 ]] && echo "ok     $name"
    else
        FAIL_NAMES+=("$name")
        DETAILS+=("$(cat "$tmp")")
        if [[ "$JSON" -eq 0 ]]; then
            echo "falha  $name"
            sed 's/^/       /' "$tmp"
        fi
    fi
    rm -f "$tmp"
}

json_escape() {
    local value="$1"
    value="${value//\\/\\\\}"
    value="${value//\"/\\\"}"
    value="${value//$'\n'/\\n}"
    printf '%s' "$value"
}

main() {
    local arg
    for arg in "$@"; do
        case "$arg" in
            --json) JSON=1 ;;
            --help|-h) usage; return 0 ;;
            *) echo "opção desconhecida: $arg" >&2; usage >&2; return 2 ;;
        esac
    done

    run_check "sintaxe-bash" check_bash_syntax
    run_check "self-tests" check_selftests
    run_check "referências-internas" check_references
    run_check "paths-documentais" bash "$SCRIPT_DIR/audit-docs-paths.sh" --quiet
    run_check "agent-skill-sync" check_agent_skill_sync
    run_check "roster" check_roster
    run_check "arquivos-obrigatórios" check_required_files

    local total=${#CHECK_NAMES[@]} failures=${#FAIL_NAMES[@]}
    if [[ "$JSON" -eq 1 ]]; then
        local arr="[" i
        for ((i=0; i<failures; i++)); do
            [[ "$i" -gt 0 ]] && arr+=","
            arr+="{\"check\":\"$(json_escape "${FAIL_NAMES[$i]}")\",\"detail\":\"$(json_escape "${DETAILS[$i]}")\"}"
        done
        arr+="]"
        printf '{"ok":%s,"checks":%d,"failures":%d,"details":%s}\n' \
            "$([[ "$failures" -eq 0 ]] && echo true || echo false)" "$total" "$failures" "$arr"
    else
        if [[ "$failures" -eq 0 ]]; then
            echo "doctor: íntegro ($total verificações)"
        else
            echo "doctor: $failures de $total verificações falharam" >&2
        fi
    fi
    [[ "$failures" -eq 0 ]]
}

[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0
main "$@"
