#!/usr/bin/env bash
# panes.sh — fachada única do atuador de panes do /mosk-orq (ADR-0010/0014).
# Resolve SE há atuador disponível e delega o argv inalterado ao driver.
#
# Por que a fachada sobrevive com um único backend (ADR-0014 §2): é onde vive a
# degradação `none` — requisito, não conveniência, porque o MOSK precisa rodar em
# projetos sem atuador nenhum —, mantém o orq.md desacoplado do CLI do Orca, e é
# o ponto onde a seleção de tier do fan-out é resolvida (ADR-0013 §3).
#
# NÃO decide o pipeline — o cérebro é legal_moves.sh / pipeline-graph.yaml, e o
# humano decide toda bifurcação (ADR-0006/0012).
#
# Contrato repassado ao driver:
#   check | tokens | spawn | send | wait-idle | read | close | managed
#
# Usage:
#   panes.sh driver [--json]        há atuador ativo e por quê
#   panes.sh tier [--json]          qual tier de fan-out o ambiente oferece
#   panes.sh <subcomando> [args]    delega ao driver
#   panes.sh --help
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

usage() {
    cat <<'EOF'
panes.sh <subcomando> [args]  — fachada do atuador de panes do /mosk-orq.

Subcomandos proprios:
  driver [--json]                         ha atuador ativo + motivo
  tier [--json]                           tier de fan-out disponivel (ADR-0013)

Delegados ao driver (backend Orca):
  check [--json]                          atuador disponivel? (go/no-go)
  tokens <pane> [--ceiling N] [--json]    tokens usados vs teto
  spawn --cwd <path> [--label <name>] [--focus] -- <argv...>
                                          abre um pane worker; imprime o id
  send <pane> <text>                      injeta <text> e submete
  wait-idle <pane> [--timeout <ms>]       espera o agente ficar idle
  read <pane> [--lines <n>]               saida recente do pane
  close <pane>                            fecha o pane
  managed [--cwd <path>]                  panes geridos (JSON cru)

Camada nativa de orquestracao (orchestration.orca.native_tasks):
  native | task-create | task-list | dispatch | await | ask | reply
  | gate-create | gate-resolve

Opcoes globais:
  --help,-h   esta ajuda

Escolha do atuador, nesta precedencia:
  1. env MOSK_ORQ_DRIVER, se definida
  2. orchestration.driver no core-config.yaml (auto | orca | none)
  3. em `auto`: exige sessao DENTRO da IDE do Orca **e** `check` passando.
     Ter o binario no PATH nao basta — `spawn` cria terminais dentro do app,
     e fora da IDE isso abriria paineis num app que voce nao esta usando.
  4. nenhum -> `none` (o /mosk-orq degrada para o fluxo single-pane)

`driver: herdr` (backend removido no ADR-0014) falha com aviso de migracao.
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

# ─────────────────────── sondagem do backend ───────────────────────
_probe_cache=""
_probe_json=""

backend_ok() {
    if [[ -z "$_probe_cache" ]]; then
        if _probe_json="$(bash "$SCRIPT_DIR/orca.sh" check --json 2>/dev/null)"; then
            _probe_cache=yes
        else
            _probe_cache=no
        fi
    fi
    [[ "$_probe_cache" == yes ]]
}

# Motivo estruturado da última sondagem: orca-not-found | runtime-unavailable.
probe_reason() {
    printf '%s' "$_probe_json" | sed -nE 's/.*"reason":"([^"]*)".*/\1/p'
}

# Estamos rodando DENTRO da IDE do Orca? É o sinal de ativação (ADR-0014 §3.1) —
# não a presença do binário, que só prova instalação.
in_orca_session() { [[ -n "${ORCA_PANE_KEY:-}${ORCA_WORKTREE_ID:-}${ORCA_TERMINAL_HANDLE:-}" ]]; }

# ─────────────────────── resolução do driver ───────────────────────
RESOLVED_DRIVER=""
RESOLVED_REASON=""
RESOLVED_ACTION=""

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
        herdr)
            echo "erro: o backend 'herdr' foi removido (ADR-0014); o Orca e o unico atuador." >&2
            echo "  Ajuste orchestration.driver em $from para 'auto' (ou 'orca'/'none')." >&2
            echo "  A chave orchestration.herdr, se existir, pode ser apagada." >&2
            exit 1
            ;;
        orca|none)
            RESOLVED_DRIVER="$want"
            RESOLVED_REASON="fixado em $from"
            return 0
            ;;
        auto) ;;
        *)
            echo "aviso: driver '$want' desconhecido em $from; usando auto." >&2
            ;;
    esac

    # Em `auto` são DOIS requisitos, não um: estar dentro da IDE e o check passar.
    if ! in_orca_session; then
        RESOLVED_DRIVER=none
        RESOLVED_REASON="sessao fora da IDE do Orca"
        RESOLVED_ACTION="abra este projeto no Orca para orquestrar em panes"
        return 0
    fi
    if backend_ok; then
        RESOLVED_DRIVER=orca
        RESOLVED_REASON="sessao dentro do Orca"
        return 0
    fi
    RESOLVED_DRIVER=none
    case "$(probe_reason)" in
        orca-not-found)
            RESOLVED_REASON="CLI do Orca nao encontrada"
            RESOLVED_ACTION="instale o Orca (https://www.onorca.dev/)"
            ;;
        runtime-unavailable)
            RESOLVED_REASON="runtime do app Orca inacessivel"
            RESOLVED_ACTION="abra ou reinicie o app Orca"
            ;;
        *)
            RESOLVED_REASON="nenhum atuador disponivel"
            RESOLVED_ACTION="verifique a instalacao do Orca"
            ;;
    esac
    return 0
}

cmd_driver() {
    local json=0
    for a in "$@"; do [[ "$a" == "--json" ]] && json=1; done
    resolve_driver
    if [[ "$json" -eq 1 ]]; then
        echo "{\"driver\":\"$RESOLVED_DRIVER\",\"reason\":\"$RESOLVED_REASON\",\"actionable\":\"$RESOLVED_ACTION\"}"
    else
        echo "driver: $RESOLVED_DRIVER ($RESOLVED_REASON)"
        [[ -n "$RESOLVED_ACTION" ]] && echo "  -> $RESOLVED_ACTION"
    fi
    [[ "$RESOLVED_DRIVER" != none ]]
}

# ─────────────────────── tier de fan-out (ADR-0013 §3) ───────────────────────
# O Tier 1 é o único que este script pode afirmar: exige Orca dentro da IDE com a
# camada de orquestração ativa. A escolha entre Tier 2 (subagente nativo) e Tier 3
# (sequencial) é do RUNTIME que hospeda o agente — um shell não tem como saber se
# quem o chamou dispõe de tool de subagente. Por isso reportamos `2+` com
# `runtime_decides`, em vez de fingir uma certeza que não temos.
cmd_tier() {
    local json=0
    for a in "$@"; do [[ "$a" == "--json" ]] && json=1; done
    resolve_driver

    local tier reason action runtime_decides
    if [[ "$RESOLVED_DRIVER" != orca ]]; then
        tier="2+"; runtime_decides=true
        reason="$RESOLVED_REASON"
        action="$RESOLVED_ACTION"
    else
        local nat
        if nat="$(bash "$SCRIPT_DIR/orca.sh" native --json 2>/dev/null)"; then
            tier=1; runtime_decides=false
            reason="$(printf '%s' "$nat" | sed -nE 's/.*"reason":"([^"]*)".*/\1/p')"
            action=""
        else
            tier="2+"; runtime_decides=true
            reason="$(printf '%s' "$nat" | sed -nE 's/.*"reason":"([^"]*)".*/\1/p')"
            [[ -z "$reason" ]] && reason="camada de orquestracao indisponivel"
            action="habilite a orquestracao em Settings > Experimental do Orca"
        fi
    fi

    if [[ "$json" -eq 1 ]]; then
        echo "{\"tier\":\"$tier\",\"runtime_decides\":$runtime_decides,\"reason\":\"$reason\",\"actionable\":\"$action\"}"
    else
        echo "tier: $tier ($reason)"
        [[ "$runtime_decides" == true ]] && echo "  -> Tier 2 se o runtime tiver subagente nativo; senao Tier 3 (sequencial)."
        [[ -n "$action" ]] && echo "  -> $action"
    fi
    return 0
}

# ─────────────────────── degradação sem atuador ───────────────────────
no_actuator() {
    local sub="$1"; shift || true
    local json=0
    for a in "$@"; do [[ "$a" == "--json" ]] && json=1; done

    if [[ "$sub" == "check" && "$json" -eq 1 ]]; then
        echo "{\"ok\":false,\"driver\":\"none\",\"reason\":\"$RESOLVED_REASON\"}"
        return 1
    fi
    echo "erro: nenhum atuador de panes disponivel — $RESOLVED_REASON." >&2
    [[ -n "$RESOLVED_ACTION" ]] && echo "  $RESOLVED_ACTION" >&2
    echo "  O Orca e OPCIONAL: sem ele, use o fluxo single-pane normal" >&2
    echo "  (ex.: /mosk-suggestion). O pipeline roda ponta a ponta sem atuador." >&2
    return 1
}

# ─────────────────────────── dispatch ───────────────────────────
[[ $# -eq 0 ]] && { usage; exit 2; }
case "$1" in
    --help|-h) usage; exit 0 ;;
    driver) shift; cmd_driver "$@" ;;
    tier)   shift; cmd_tier "$@" ;;
    *)
        resolve_driver
        case "$RESOLVED_DRIVER" in
            orca) exec bash "$SCRIPT_DIR/orca.sh" "$@" ;;
            *)    no_actuator "$@" ;;
        esac
        ;;
esac
