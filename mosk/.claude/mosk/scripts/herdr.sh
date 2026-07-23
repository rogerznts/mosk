#!/usr/bin/env bash
# herdr.sh — wrapper mecânico da control API do Herdr (herdr.dev) para o
# orquestrador /mosk-orq. É o ATUADOR: spawna panes, injeta input, espera o
# agente ficar idle, lê a saída, mede tokens e fecha panes. NUNCA decide o
# pipeline — o cérebro é legal_moves.sh / pipeline-graph.yaml, e o humano
# decide toda bifurcação (ADR-0006/0009).
#
# Dependência externa OPCIONAL: o binário `herdr`. Sem ele, `check` falha
# graciosamente (exit != 0 + mensagem) e a skill /mosk-orq degrada para
# orientação single-pane estilo /mosk-suggestion. Nunca hard-fail silencioso.
#
# Usage:
#   herdr.sh check [--json]
#   herdr.sh tokens <pane_id> [--ceiling N] [--json]
#   herdr.sh spawn --cwd <path> [--label <name>] [--split right|down] [--focus] -- <argv...>
#   herdr.sh send <pane_id> <text>
#   herdr.sh wait-idle <pane_id> [--timeout <ms>]
#   herdr.sh read <pane_id> [--lines <n>]
#   herdr.sh close <pane_id>
#   herdr.sh managed [--cwd <path>]
#   herdr.sh --help
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

DEFAULT_CEILING=800000
INSTALL_HINT='brew install herdr   # ou veja https://herdr.dev/'

usage() {
    cat <<'EOF'
herdr.sh <subcomando> [args]  — wrapper da control API do Herdr para /mosk-orq.

Subcomandos:
  check [--json]                          herdr presente + server up? (go/no-go)
  tokens <pane> [--ceiling N] [--json]    lê o contador nativo e compara ao teto
  spawn --cwd <path> [--label <name>] [--split right|down] [--workspace <id>]
        [--tab <id>] [--focus] -- <argv...>
                                          spawna um pane worker; imprime o pane_id
                                          (por padrao fixa no space/tab atual do
                                          orquestrador via env HERDR_TAB_ID)
  send <pane> <text>                      injeta <text> e submete (Enter)
  wait-idle <pane> [--timeout <ms>]       espera o agente ficar idle
  read <pane> [--lines <n>]               imprime a saída recente do pane
  close <pane>                            fecha o pane
  managed [--cwd <path>]                  lista panes geridos (JSON do agent list)

Opcoes globais:
  --help,-h   esta ajuda

Config: o teto de tokens padrao vem de core-config.yaml
(orchestration.herdr.context_token_ceiling); fallback 800000. Override por
--ceiling ou pela env MOSK_CONTEXT_TOKEN_CEILING.
EOF
}

# --- presença do binário (degradação graciosa) ---
has_herdr() { command -v herdr >/dev/null 2>&1; }

require_herdr() {
    if ! has_herdr; then
        echo "erro: o binario 'herdr' nao esta no PATH." >&2
        echo "  O /mosk-orq precisa do Herdr (multiplexer de agentes) como atuador." >&2
        echo "  Instale com: $INSTALL_HINT" >&2
        echo "  Sem ele, use o fluxo single-pane normal (ex.: /mosk-suggestion)." >&2
        return 1
    fi
    return 0
}

# --- teto de tokens: env > --ceiling > core-config > default ---
config_ceiling() {
    local cfg val
    cfg="$(core_config_file 2>/dev/null || true)"
    if [[ -n "$cfg" && -f "$cfg" ]]; then
        # a chave é única no arquivo — grep direto é robusto sem parser aninhado
        val="$(grep -E '^[[:space:]]*context_token_ceiling:' "$cfg" 2>/dev/null | head -1 | sed -E 's/.*:[[:space:]]*//; s/[^0-9].*//')"
        [[ -n "$val" ]] && { echo "$val"; return 0; }
    fi
    echo "$DEFAULT_CEILING"
}

# --- extrai o pane_id de uma saída JSON do herdr ---
_pane_id_from_json() {
    grep -o '"pane_id":"[^"]*"' | head -1 | cut -d'"' -f4
}

# --- extrai a contagem de tokens do texto de um pane ---
# Regra: ignora linhas de dica ("save"/"/clear"/"ctx left") e pega a ÚLTIMA
# ocorrência de "<n>[k] tokens" — o contador de contexto nativo do Claude Code.
# Se nada casar, não imprime nada (o chamador trata como desconhecido).
_extract_tokens() {
    awk '
        function tonum(s,   k){
            k=0
            if (s ~ /[kK]/) { k=1; sub(/[kK]/,"",s) }
            sub(/,/,".",s)
            if (k) return int((s+0)*1000)
            return int(s+0)
        }
        {
            l=$0; low=tolower(l)
            if (low ~ /save|clear|ctx left|context left/) next
            while (match(l, /[0-9][0-9.,]*[ ]*[kK]?[ ]*tokens/)) {
                m=substr(l,RSTART,RLENGTH)
                num=m; sub(/[ ]*tokens.*/,"",num); gsub(/ /,"",num)
                found=tonum(num)
                l=substr(l,RSTART+RLENGTH)
            }
        }
        END { if (found != "") print found }
    '
}

# --- read cru → texto limpo do pane (JSON envelope do herdr) ---
_read_raw() {
    local pane="$1"; shift
    herdr agent read "$pane" --source recent "$@" 2>/dev/null
}
_read_text() {
    local raw="$1"
    if command -v python3 >/dev/null 2>&1; then
        printf '%s' "$raw" | python3 -c 'import sys,json;
try:
    print(json.load(sys.stdin)["result"]["read"]["text"])
except Exception:
    pass' 2>/dev/null
    else
        # fallback best-effort: descarta o envelope e desescapa \n
        printf '%s' "$raw" | sed -E 's/.*"text":"//; s/"[,}].*$//' | sed 's/\\n/\n/g'
    fi
}

# ─────────────────────────── subcomandos ───────────────────────────

cmd_check() {
    local json=0
    for a in "$@"; do [[ "$a" == "--json" ]] && json=1; done
    if ! has_herdr; then
        if [[ "$json" -eq 1 ]]; then
            echo '{"ok":false,"reason":"herdr-not-found","install":"'"$INSTALL_HINT"'"}'
        else
            require_herdr || true
        fi
        return 1
    fi
    local status server_ok=false
    status="$(herdr status 2>/dev/null || true)"
    echo "$status" | grep -qiE 'status:[[:space:]]*running' && server_ok=true
    if [[ "$json" -eq 1 ]]; then
        echo "{\"ok\":$server_ok,\"herdr\":true,\"server_running\":$server_ok}"
    else
        if [[ "$server_ok" == true ]]; then
            echo "herdr: ok (binario presente, server rodando)."
        else
            echo "herdr: binario presente, mas o server nao esta rodando." >&2
            echo "  Inicie uma sessao Herdr (ex.: 'herdr') e tente de novo." >&2
        fi
    fi
    [[ "$server_ok" == true ]]
}

cmd_tokens() {
    require_herdr || return 1
    local pane="" ceiling="" json=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --ceiling) ceiling="$2"; shift 2 ;;
            --json) json=1; shift ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) pane="$1"; shift ;;
        esac
    done
    [[ -n "$pane" ]] || { echo "erro: informe o pane_id." >&2; return 2; }
    [[ -n "$ceiling" ]] || ceiling="${MOSK_CONTEXT_TOKEN_CEILING:-$(config_ceiling)}"

    local text used over
    text="$(_read_text "$(_read_raw "$pane")")"
    used="$(printf '%s\n' "$text" | _extract_tokens)"

    if [[ -z "$used" ]]; then
        over="unknown"
        if [[ "$json" -eq 1 ]]; then
            echo "{\"pane\":\"$pane\",\"used\":null,\"ceiling\":$ceiling,\"over\":\"unknown\"}"
        else
            echo "used=? ceiling=$ceiling over=unknown"
            echo "aviso: contador de tokens nao parseado; gatilho de teto ignorado." >&2
        fi
        return 0
    fi

    if [[ "$used" -ge "$ceiling" ]]; then over=true; else over=false; fi
    if [[ "$json" -eq 1 ]]; then
        echo "{\"pane\":\"$pane\",\"used\":$used,\"ceiling\":$ceiling,\"over\":$over}"
    else
        echo "used=$used ceiling=$ceiling over=$over"
    fi
}

cmd_spawn() {
    require_herdr || return 1
    local cwd="" label="claude" split="right" focus="--no-focus"
    local workspace="" tab=""
    local -a argv=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cwd) cwd="$2"; shift 2 ;;
            --label) label="$2"; shift 2 ;;
            --split) split="$2"; shift 2 ;;
            --workspace) workspace="$2"; shift 2 ;;
            --tab) tab="$2"; shift 2 ;;
            --focus) focus="--focus"; shift ;;
            --no-focus) focus="--no-focus"; shift ;;
            --) shift; argv=("$@"); break ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) echo "argumento inesperado: $1 (use -- antes do argv)" >&2; return 2 ;;
        esac
    done
    [[ -n "$cwd" ]] || { echo "erro: --cwd e obrigatorio." >&2; return 2; }
    [[ ${#argv[@]} -gt 0 ]] || argv=("$label")

    # Fixa o pane no space/tab do PRÓPRIO orquestrador por padrão (env HERDR_*),
    # para nunca seguir o pane focado pelo usuário em outro space nem criar um
    # workspace novo. --tab tem precedência; senao usa --workspace.
    [[ -z "$tab" && -z "$workspace" ]] && tab="${HERDR_TAB_ID:-}"
    [[ -z "$tab" && -z "$workspace" ]] && workspace="${HERDR_WORKSPACE_ID:-}"

    local -a target=()
    if [[ -n "$tab" ]]; then
        target=(--tab "$tab")
    elif [[ -n "$workspace" ]]; then
        target=(--workspace "$workspace")
    fi

    local out pane
    out="$(herdr agent start "$label" --cwd "$cwd" "${target[@]}" --split "$split" "$focus" -- "${argv[@]}" 2>&1)"
    pane="$(printf '%s' "$out" | _pane_id_from_json)"
    if [[ -z "$pane" ]]; then
        echo "erro: nao consegui obter o pane_id do spawn." >&2
        printf '%s\n' "$out" >&2
        return 1
    fi
    echo "$pane"
}

cmd_send() {
    require_herdr || return 1
    local pane="$1"; shift || true
    local text="$*"
    [[ -n "$pane" && -n "$text" ]] || { echo "erro: uso: send <pane> <text>" >&2; return 2; }
    herdr agent send "$pane" "$text" >/dev/null
    # respiro entre injetar o texto e submeter: sem ele, a TUI do agente pode
    # descartar o Enter antes de renderizar o texto (visto em teste). Ajustavel
    # via MOSK_HERDR_SEND_DELAY (segundos).
    sleep "${MOSK_HERDR_SEND_DELAY:-0.6}"
    herdr pane send-keys "$pane" Enter >/dev/null
}

cmd_wait_idle() {
    require_herdr || return 1
    local pane="" timeout="120000"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --timeout) timeout="$2"; shift 2 ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) pane="$1"; shift ;;
        esac
    done
    [[ -n "$pane" ]] || { echo "erro: informe o pane_id." >&2; return 2; }
    # Evita a race pós-send: logo apos submeter, o agente ainda esta idle por um
    # instante e um wait-idle imediato retornaria cedo. Primeiro espera ele SAIR
    # do idle (entrar em working), com uma janela curta; se nao entrar nessa
    # janela, assume que ja terminou e segue para o wait-idle normal.
    herdr agent wait "$pane" --status working --timeout "${MOSK_HERDR_START_GRACE:-8000}" >/dev/null 2>&1 || true
    herdr agent wait "$pane" --status idle --timeout "$timeout" >/dev/null
}

cmd_read() {
    require_herdr || return 1
    local pane="" lines=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --lines) lines="$2"; shift 2 ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) pane="$1"; shift ;;
        esac
    done
    [[ -n "$pane" ]] || { echo "erro: informe o pane_id." >&2; return 2; }
    local -a extra=()
    [[ -n "$lines" ]] && extra=(--lines "$lines")
    _read_text "$(_read_raw "$pane" "${extra[@]}")"
}

cmd_close() {
    require_herdr || return 1
    local pane="$1"
    [[ -n "$pane" ]] || { echo "erro: informe o pane_id." >&2; return 2; }
    herdr pane close "$pane" >/dev/null
}

cmd_managed() {
    require_herdr || return 1
    local cwd=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cwd) cwd="$2"; shift 2 ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) shift ;;
        esac
    done
    # Registro vivo: o agent list ja traz cwd, titulo e agent_status por pane.
    # O filtro por cwd fica no chamador (a skill) — aqui devolvemos o JSON cru
    # ou, com --cwd, as linhas de pane cujo cwd casa (grep simples).
    if [[ -z "$cwd" ]]; then
        herdr agent list 2>/dev/null
    else
        herdr agent list 2>/dev/null | grep -o "{[^{}]*\"cwd\":\"$cwd\"[^{}]*}" || true
    fi
}

# ─────────────────────────── dispatch ───────────────────────────
[[ $# -eq 0 ]] && { usage; exit 2; }
case "$1" in
    --help|-h) usage; exit 0 ;;
    check)     shift; cmd_check "$@" ;;
    tokens)    shift; cmd_tokens "$@" ;;
    spawn)     shift; cmd_spawn "$@" ;;
    send)      shift; cmd_send "$@" ;;
    wait-idle) shift; cmd_wait_idle "$@" ;;
    read)      shift; cmd_read "$@" ;;
    close)     shift; cmd_close "$@" ;;
    managed)   shift; cmd_managed "$@" ;;
    *) echo "subcomando desconhecido: $1" >&2; usage; exit 2 ;;
esac
