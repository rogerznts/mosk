#!/usr/bin/env bash
# legal_moves.sh — compute the LEGAL next moves from a given pipeline phase,
# reading the single source of truth: pipeline-graph.yaml (ADR-0006/0007).
#
# INVARIANTE: este script NUNCA toma uma aresta. Ele avalia os guards `fact`
# mecanicamente, sinaliza os guards `judgment` para o agente decidir, e
# apresenta as jogadas legais. Quem decide (go/escalate/skip/override) é o
# humano. Nenhum agente é invocado aqui.
#
# Usage:
#   legal_moves.sh <current_phase> [--json]
#   legal_moves.sh __start__            # roteamento pré-spec (base_ready?)
#   legal_moves.sh --help
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

usage() {
    cat <<'EOF'
legal_moves.sh <current_phase> [--json]

Lista as jogadas legais a partir de <current_phase>, lendo pipeline-graph.yaml.
Guards `fact` sao avaliados aqui (disco); guards `judgment` sao sinalizados
para o agente avaliar. Escalacoes disponiveis da fase tambem sao listadas.
O script NUNCA toma a aresta — apenas apresenta.

Fases (ponteiro): specify | plan | tasks | implement | qa-gate | archived
Entrada especial: __start__ (roteamento antes de existir uma spec)

Opcoes:
  --json     saida em JSON
  --help,-h  esta ajuda
EOF
}

PHASE=""
JSON=0
for arg in "$@"; do
    case "$arg" in
        --help|-h) usage; exit 0 ;;
        --json) JSON=1 ;;
        -*) echo "opcao desconhecida: $arg" >&2; usage; exit 2 ;;
        *) PHASE="$arg" ;;
    esac
done

if [[ -z "$PHASE" ]]; then
    echo "erro: informe a fase atual (ou __start__)." >&2
    usage
    exit 2
fi

REPO_ROOT="$(get_repo_root)"
eval "$(get_feature_paths 2>/dev/null | grep -E '^FEATURE_DIR=')" || true

# --- fact guard evaluators (mecânicos, verificáveis em disco) ---
_prd_ready() { [[ -d "$REPO_ROOT/docs/prd" && -n "$(ls -A "$REPO_ROOT/docs/prd" 2>/dev/null)" ]]; }
_gate_status() {
    local gf="${FEATURE_DIR:-}/gate.yaml"
    [[ -f "$gf" ]] || return 0
    awk '/^[[:space:]]*gate[[:space:]]*:/ { sub(/^[[:space:]]*gate[[:space:]]*:[[:space:]]*/,""); gsub(/["'\'' ]/,""); print; exit }' "$gf"
}
eval_fact_guard() {
    case "$1" in
        base_ready)             _prd_ready ;;
        base_missing)           ! _prd_ready ;;
        gate_pass)              local s; s="$(_gate_status)"; [[ "$s" == "PASS" || "$s" == "WAIVED" ]] ;;
        gate_concerns_or_fail)  local s; s="$(_gate_status)"; [[ "$s" == "CONCERNS" || "$s" == "FAIL" ]] ;;
        *) return 1 ;;
    esac
}

# --- escalations available from this phase ---
escalations_from() {
    local gf; gf="$(graph_file)"
    [[ -f "$gf" ]] || return 0
    awk -v ph="$PHASE" '
        function getf(s, name,   re, v) {
            re = name ":[[:space:]]*"
            if (match(s, re)) { v = substr(s, RSTART+RLENGTH); sub(/[,}].*/,"",v); gsub(/^[[:space:]]+|[[:space:]]+$/,"",v); gsub(/^"|"$/,"",v); return v }
            return ""
        }
        /^[^[:space:]#]/ { inb = ($0 ~ /^escalations:/) }
        inb && /^[[:space:]]*-[[:space:]]*\{/ {
            if (!match($0, /from:[[:space:]]*\[[^]]*\]/)) next
            fl = substr($0, RSTART, RLENGTH); sub(/from:[[:space:]]*\[/,"",fl); sub(/\]/,"",fl); gsub(/[[:space:]]/,"",fl)
            n = split(fl, a, ","); hit = 0
            for (i = 1; i <= n; i++) if (a[i] == ph) hit = 1
            if (!hit) next
            printf "%s|%s\n", getf($0, "to"), getf($0, "signal")
        }
    ' "$gf"
}

# --- collect moves ---
moves_json="["
first=1
human_moves=""

while IFS='|' read -r to guard def; do
    [[ -z "$to" ]] && continue
    offered=1; note=""; kind=""
    if [[ -n "$guard" ]]; then
        kind="$(guard_kind "$guard")"
        case "$kind" in
            fact)
                if eval_fact_guard "$guard"; then note="[guard: $guard ✓]"; else offered=0; fi
                ;;
            judgment)
                note="[avaliar: $(guard_question "$guard")]"
                ;;
            *)
                note="[guard: $guard (?)]"
                ;;
        esac
    fi
    [[ "$offered" -eq 1 ]] || continue
    tag=""; [[ "$def" == "true" ]] && tag=" (default)"
    human_moves+="  → ${to}${tag} ${note}"$'\n'
    [[ $first -eq 0 ]] && moves_json+=","
    first=0
    moves_json+="{\"to\":\"$to\",\"guard\":\"$guard\",\"kind\":\"$kind\",\"default\":$([[ "$def" == "true" ]] && echo true || echo false)}"
done < <(graph_edges_from "$PHASE")

moves_json+="]"

# --- escalations ---
esc_json="["; efirst=1; human_esc=""
while IFS='|' read -r eto esig; do
    [[ -z "$eto" ]] && continue
    human_esc+="  ↩ ${eto}  [escalação: ${esig} → volta pra ${PHASE}]"$'\n'
    [[ $efirst -eq 0 ]] && esc_json+=","
    efirst=0
    esc_json+="{\"to\":\"$eto\",\"signal\":\"$esig\",\"return_to\":\"origin\"}"
done < <(escalations_from)
esc_json+="]"

if [[ "$JSON" -eq 1 ]]; then
    printf '{"phase":"%s","moves":%s,"escalations":%s}\n' "$PHASE" "$moves_json" "$esc_json"
    exit 0
fi

echo "fase atual: $PHASE"
if [[ -n "$human_moves" ]]; then
    echo "jogadas legais:"
    printf '%s' "$human_moves"
else
    echo "jogadas legais: (nenhuma aresta satisfeita)"
fi
if [[ -n "$human_esc" ]]; then
    echo "escalações disponíveis:"
    printf '%s' "$human_esc"
fi
echo
echo "O humano decide (go / escalate / skip / override). Nada foi executado."
