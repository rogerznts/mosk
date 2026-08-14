#!/usr/bin/env bash
# check-ship-ready.sh — valida se a spec ativa do branch está "pronta pra mergear",
# a fonte ÚNICA de "esta spec está fechada". As camadas de guardrail (hook do
# Claude Code, CI/branch protection, /tea-open-pr) só chamam este script.
#
# Falha (exit 1) se a spec do branch tiver pontas soltas:
#   - current_phase != archived (não passou pelo archive do pipeline);
#   - artefatos com `promote:` (copy/append) cujo alvo ainda não existe;
#   - working tree sujo (mudanças não commitadas).
# Branch sem spec ativa (base branch / mudança não-spec) → passa (exit 0): o
# gate é sobre specs MOSK, não sobre todo branch.
#
# Usage:
#   check-ship-ready.sh [--json] [--help]
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

usage() {
    cat <<'EOF'
check-ship-ready.sh [--json]

Valida se a spec ativa do branch atual esta "pronta pra mergear" (fonte unica
de "spec fechada"). Exit 0 = pronta (ou sem spec no branch); exit 1 = pontas
soltas (lista os motivos); exit 2 = erro de uso.

Checagens (quando ha spec ativa):
  - current_phase == archived
  - nenhum artefato promote (copy/append) com alvo faltando
  - working tree limpo

Opcoes:
  --json     saida em JSON: {"ready":bool,"spec":"...","phase":"...","failures":[...]}
  --help,-h  esta ajuda
EOF
}

JSON=0
for arg in "$@"; do
    case "$arg" in
        --json) JSON=1 ;;
        --help|-h) usage; exit 0 ;;
        -*) echo "opcao desconhecida: $arg" >&2; usage; exit 2 ;;
    esac
done

REPO_ROOT="$(get_repo_root)"
FEATURE_DIR=""
eval "$(get_feature_paths 2>/dev/null | grep -E '^FEATURE_DIR=')" || true

# --- acumulador de falhas ---
failures=()
add_fail() { failures+=("$1"); }

emit() {
    local ready="true"; [[ ${#failures[@]} -gt 0 ]] && ready="false"
    if [[ "$JSON" -eq 1 ]]; then
        local arr="["; local first=1
        for f in "${failures[@]}"; do
            [[ $first -eq 0 ]] && arr+=","
            first=0
            arr+="\"$(printf '%s' "$f" | sed 's/\\/\\\\/g; s/"/\\"/g')\""
        done
        arr+="]"
        printf '{"ready":%s,"spec":"%s","phase":"%s","failures":%s}\n' \
            "$ready" "${SPEC_ID:-}" "${PHASE:-}" "$arr"
    else
        if [[ "$ready" == "true" ]]; then
            echo "ship-ready: OK${SPEC_ID:+ (spec $SPEC_ID)}"
        else
            echo "ship-ready: NAO — pontas soltas${SPEC_ID:+ na spec $SPEC_ID}:" >&2
            for f in "${failures[@]}"; do echo "  ✗ $f" >&2; done
            echo "  → rode o archive da spec (/mosk-dev archive) e commite antes do PR." >&2
        fi
    fi
    [[ "$ready" == "true" ]]
}

# --- sem spec ativa: nada a validar ---
if [[ -z "$FEATURE_DIR" || ! -d "$FEATURE_DIR" || ! -f "$FEATURE_DIR/spec-meta.yaml" ]]; then
    SPEC_ID=""; PHASE=""
    [[ "$JSON" -eq 1 ]] && echo '{"ready":true,"spec":"","phase":"","failures":[]}' \
        || echo "ship-ready: OK (branch sem spec ativa — nada a validar)"
    exit 0
fi

SPEC_ID="$(read_spec_meta "$FEATURE_DIR" spec_id)"
PHASE="$(read_spec_meta "$FEATURE_DIR" current_phase)"

# 1. fase precisa estar arquivada
if [[ "$PHASE" != "archived" ]]; then
    add_fail "current_phase='$PHASE' (esperado 'archived'; a spec nao passou pelo archive)"
fi

# 2. artefatos promote (copy/append) com alvo faltando
while IFS= read -r pf; do
    [[ -n "$pf" ]] || continue
    local_target="$(awk -F': *' '/^promote:/{print $2; exit}' "$pf" | tr -d '"'"'"' ')"
    local_mode="$(awk -F': *' '/^promote_mode:/{print $2; exit}' "$pf" | tr -d '"'"'"' ')"
    [[ -z "$local_target" ]] && continue
    [[ "$local_mode" == "manual" ]] && continue   # manual: aplicado a mao, nao gateia
    if [[ ! -e "$REPO_ROOT/$local_target" ]]; then
        add_fail "promote nao aplicado: $(basename "$pf") -> $local_target (rode o archive)"
    fi
done < <(grep -rl '^promote:' "$FEATURE_DIR" 2>/dev/null || true)

# 3. working tree limpo
if has_git && [[ -n "$(git -C "$REPO_ROOT" status --porcelain 2>/dev/null)" ]]; then
    add_fail "working tree sujo (mudancas nao commitadas)"
fi

emit
