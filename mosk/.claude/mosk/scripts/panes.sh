#!/usr/bin/env bash
# panes.sh — fachada única do atuador de panes do /mosk-orq (ADR-0010).
# Resolve QUAL backend está ativo (herdr | orca | none) e delega o argv
# inalterado ao driver correspondente. É o único caminho que o agente conhece:
# assim, trocar ou acrescentar backend não custa uma linha de prompt.
#
# NÃO decide o pipeline — o cérebro é legal_moves.sh / pipeline-graph.yaml, e o
# humano decide toda bifurcação (ADR-0006/0009).
#
# Contrato repassado aos drivers:
#   check | tokens | spawn | send | wait-idle | read | close | managed
#
# Usage:
#   panes.sh driver [--json]        qual backend está ativo e por quê
#   panes.sh <subcomando> [args]    delega ao driver ativo
#   panes.sh --help
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

usage() {
    cat <<'EOF'
panes.sh <subcomando> [args]  — fachada do atuador de panes do /mosk-orq.

Subcomandos proprios:
  driver [--json]                         backend ativo + motivo da escolha

Delegados ao driver ativo (mesmo contrato nos dois backends):
  check [--json]                          atuador disponivel? (go/no-go)
  tokens <pane> [--ceiling N] [--json]    tokens usados vs teto
  spawn --cwd <path> [--label <name>] [--focus] -- <argv...>
                                          abre um pane worker; imprime o id
  send <pane> <text>                      injeta <text> e submete
  wait-idle <pane> [--timeout <ms>]       espera o agente ficar idle
  read <pane> [--lines <n>]               saida recente do pane
  close <pane>                            fecha o pane
  managed [--cwd <path>]                  panes geridos (JSON cru)

Exclusivos do backend orca (camada nativa, opt-in). Nos demais backends
respondem `unsupported` com exit 3, sem quebrar o fluxo:
  native | task-create | task-list | dispatch | await | gate-create | gate-resolve

Opcoes globais:
  --help,-h   esta ajuda

Escolha do backend, nesta precedencia:
  1. env MOSK_ORQ_DRIVER, se definida
  2. orchestration.driver no core-config.yaml (auto | herdr | orca | none)
  3. em `auto`: o ambiente da sessao atual (variaveis ORCA_* ou HERDR_*)
  4. em `auto`: o primeiro backend cujo `check` passar (orca, depois herdr)
  5. nenhum -> `none` (o /mosk-orq degrada para o fluxo single-pane)
EOF
}

# ─────────────────────── leitura da config ───────────────────────
# orchestration.driver — chave de segundo nível, lida com o mesmo padrão awk
# usado por _core_config_max_retries em common.sh.
config_driver() {
    local cc
    cc="$(core_config_file 2>/dev/null || true)"
    [[ -n "$cc" && -f "$cc" ]] || return 0
    awk '
        /^[^[:space:]#]/ { in_orch = ($0 ~ /^orchestration:/) }
        in_orch && /^[[:space:]]+driver[[:space:]]*:/ {
            sub(/^[[:space:]]+driver[[:space:]]*:[[:space:]]*/, "")
            sub(/[[:space:]]*#.*$/, "")
            gsub(/["'\'' ]/, "")
            print; exit
        }
    ' "$cc"
}

# ─────────────────────── sondagem dos backends ───────────────────────
_probe_cache_orca=""
_probe_cache_herdr=""

backend_ok() {
    local b="$1"
    case "$b" in
        orca)
            [[ -n "$_probe_cache_orca" ]] || {
                if bash "$SCRIPT_DIR/orca.sh" check --json >/dev/null 2>&1; then
                    _probe_cache_orca=yes
                else
                    _probe_cache_orca=no
                fi
            }
            [[ "$_probe_cache_orca" == yes ]]
            ;;
        herdr)
            [[ -n "$_probe_cache_herdr" ]] || {
                if bash "$SCRIPT_DIR/herdr.sh" check --json >/dev/null 2>&1; then
                    _probe_cache_herdr=yes
                else
                    _probe_cache_herdr=no
                fi
            }
            [[ "$_probe_cache_herdr" == yes ]]
            ;;
        *) return 1 ;;
    esac
}

# Estamos rodando DENTRO de um pane de qual multiplexer? É o sinal mais
# confiável de desempate quando os dois estão instalados.
in_orca_session()  { [[ -n "${ORCA_PANE_KEY:-}${ORCA_WORKTREE_ID:-}${ORCA_TERMINAL_HANDLE:-}" ]]; }
in_herdr_session() { [[ -n "${HERDR_TAB_ID:-}${HERDR_WORKSPACE_ID:-}${HERDR_PANE_ID:-}" ]]; }

# ─────────────────────── resolução do driver ───────────────────────
RESOLVED_DRIVER=""
RESOLVED_REASON=""

resolve_driver() {
    [[ -n "$RESOLVED_DRIVER" ]] && return 0
    local want="${MOSK_ORQ_DRIVER:-}"
    local from="env"
    if [[ -z "$want" ]]; then
        want="$(config_driver)"
        from="core-config"
    fi
    [[ -z "$want" ]] && { want=auto; from="default"; }

    case "$want" in
        herdr|orca|none)
            RESOLVED_DRIVER="$want"
            RESOLVED_REASON="fixado em $from"
            return 0
            ;;
        auto) ;;
        *)
            echo "aviso: driver '$want' desconhecido em $from; usando auto." >&2
            ;;
    esac

    if in_orca_session && backend_ok orca; then
        RESOLVED_DRIVER=orca
        RESOLVED_REASON="sessao dentro do Orca"
        return 0
    fi
    if in_herdr_session && backend_ok herdr; then
        RESOLVED_DRIVER=herdr
        RESOLVED_REASON="sessao dentro do Herdr"
        return 0
    fi
    if backend_ok orca; then
        RESOLVED_DRIVER=orca
        RESOLVED_REASON="unico/primeiro backend disponivel"
        return 0
    fi
    if backend_ok herdr; then
        RESOLVED_DRIVER=herdr
        RESOLVED_REASON="unico/primeiro backend disponivel"
        return 0
    fi
    RESOLVED_DRIVER=none
    RESOLVED_REASON="nenhum atuador disponivel"
    return 0
}

cmd_driver() {
    local json=0
    for a in "$@"; do [[ "$a" == "--json" ]] && json=1; done
    resolve_driver
    if [[ "$json" -eq 1 ]]; then
        echo "{\"driver\":\"$RESOLVED_DRIVER\",\"reason\":\"$RESOLVED_REASON\"}"
    else
        echo "driver: $RESOLVED_DRIVER ($RESOLVED_REASON)"
    fi
    [[ "$RESOLVED_DRIVER" != none ]]
}

# ─────────────── subcomandos exclusivos da camada nativa ───────────────
# Só o backend Orca os implementa (ADR-0010). No Herdr respondemos
# `unsupported` com exit 3 — um código próprio, para o chamador distinguir
# "este backend não faz isso" de "isto falhou".
is_native_subcommand() {
    case "$1" in
        native|task-create|task-list|dispatch|await|gate-create|gate-resolve) return 0 ;;
        *) return 1 ;;
    esac
}

unsupported() {
    local sub="$1" driver="$2"
    local json=0
    shift 2 || true
    for a in "$@"; do [[ "$a" == "--json" ]] && json=1; done
    if [[ "$json" -eq 1 ]]; then
        echo "{\"ok\":false,\"driver\":\"$driver\",\"reason\":\"unsupported\",\"subcommand\":\"$sub\"}"
    else
        echo "aviso: '$sub' so existe no backend orca; driver ativo e '$driver'." >&2
    fi
    return 3
}

# ─────────────────────── degradação sem atuador ───────────────────────
no_actuator() {
    local sub="$1"; shift || true
    local json=0
    for a in "$@"; do [[ "$a" == "--json" ]] && json=1; done

    if [[ "$sub" == "check" && "$json" -eq 1 ]]; then
        echo '{"ok":false,"driver":"none","reason":"no-actuator"}'
        return 1
    fi
    echo "erro: nenhum atuador de panes disponivel (Herdr ou Orca)." >&2
    echo "  Orca:  https://www.onorca.dev/ (a CLI vem com o app; o app precisa estar aberto)" >&2
    echo "  Herdr: brew install herdr   # ou veja https://herdr.dev/" >&2
    echo "  Sem um deles, use o fluxo single-pane normal (ex.: /mosk-suggestion)." >&2
    return 1
}

# ─────────────────────────── dispatch ───────────────────────────
[[ $# -eq 0 ]] && { usage; exit 2; }
case "$1" in
    --help|-h) usage; exit 0 ;;
    driver) shift; cmd_driver "$@" ;;
    *)
        resolve_driver
        if is_native_subcommand "$1" && [[ "$RESOLVED_DRIVER" != orca ]]; then
            unsupported "$1" "$RESOLVED_DRIVER" "$@"
            exit $?
        fi
        case "$RESOLVED_DRIVER" in
            herdr) exec bash "$SCRIPT_DIR/herdr.sh" "$@" ;;
            orca)  exec bash "$SCRIPT_DIR/orca.sh" "$@" ;;
            *)     no_actuator "$@" ;;
        esac
        ;;
esac
