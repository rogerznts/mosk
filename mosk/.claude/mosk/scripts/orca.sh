#!/usr/bin/env bash
# orca.sh — driver do atuador de panes sobre o Orca (onorca.dev), irmão do
# herdr.sh. Implementa o MESMO contrato de subcomandos, para que o /mosk-orq
# não saiba qual backend está ativo (ADR-0010). NUNCA decide o pipeline — o
# cérebro é legal_moves.sh / pipeline-graph.yaml, e o humano decide toda
# bifurcação (ADR-0006/0009).
#
# Dependência externa OPCIONAL: o app Orca + sua CLI. Sem ele, `check` falha
# graciosamente (exit != 0 + mensagem) e o /mosk-orq degrada para orientação
# single-pane estilo /mosk-suggestion. Nunca hard-fail silencioso.
#
# ATENÇÃO (Linux): `orca` cru costuma resolver para /usr/bin/orca — o LEITOR DE
# TELA do GNOME, que começa a falar na máquina do usuário. A resolução do
# executável aqui é explícita e recusa esse caminho. Nunca chame `orca` direto.
#
# Usage:
#   orca.sh check [--json]
#   orca.sh tokens <pane_id> [--ceiling N] [--json]
#   orca.sh spawn --cwd <path> [--label <name>] [--split right|down] [--focus] -- <argv...>
#   orca.sh send <pane_id> <text>
#   orca.sh wait-idle <pane_id> [--timeout <ms>]
#   orca.sh read <pane_id> [--lines <n>]
#   orca.sh close <pane_id>
#   orca.sh managed [--cwd <path>]
#   orca.sh --help
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=/dev/null
source "$SCRIPT_DIR/common.sh"

INSTALL_HINT='instale o Orca em https://www.onorca.dev/ (a CLI vem com o app)'

usage() {
    cat <<'EOF'
orca.sh <subcomando> [args]  — driver do atuador de panes sobre o Orca.

Subcomandos:
  check [--json]                          CLI presente + runtime up? (go/no-go)
  tokens <pane> [--ceiling N] [--json]    lê o contador da TUI e compara ao teto
  spawn --cwd <path> [--label <name>] [--split right|down] [--workspace <id>]
        [--tab <id>] [--focus] -- <argv...>
                                          cria um terminal worker no worktree do
                                          --cwd; imprime o handle
  send <pane> <text>                      injeta <text> e submete (Enter)
  wait-idle <pane> [--timeout <ms>]       espera a TUI do agente ficar idle
  read <pane> [--lines <n>]               imprime a saída recente do terminal
  close <pane>                            fecha o terminal
  managed [--cwd <path>]                  lista terminais geridos (JSON cru)

Camada nativa (opt-in; exige orchestration.orca.native_tasks: true):
  native [--json]                         a camada esta ligada? (exit 0 = sim)
  task-create <spec> [--deps <json_array>] [--parent <id>]
                                          cria a task; imprime o task_id
  task-list [--json] [...]                estado das tasks (prova de provenance)
  dispatch <task_id> <pane> [--no-inject] despacha; imprime o dispatch_id
  await [--timeout-ms <n>] [--types <a,b>]
                                          espera worker_done/escalation/gate
  gate-create <task_id> <pergunta> [--options <json_array>]
                                          abre o decision gate; imprime o gate_id
  gate-resolve <gate_id> <resolucao>      registra a decisao DO HUMANO

Opcoes globais:
  --help,-h   esta ajuda

Contrato: identico ao de herdr.sh — o "pane" aqui e o handle de terminal do
Orca (term_...). Prefira chamar via panes.sh, que resolve o backend e delega.

Resolucao do executavel (nesta ordem): $ORCA_CLI_COMMAND, orca-dev (quando
$ORCA_DEV_REPO_ROOT), orca-ide, e por fim `orca` — este ultimo APENAS se nao
for /usr/bin/orca (leitor de tela do GNOME).

Config: o teto de tokens padrao vem de core-config.yaml
(orchestration.context_token_ceiling); fallback 800000. Override por --ceiling
ou pela env MOSK_CONTEXT_TOKEN_CEILING.

Diferencas conhecidas em relacao ao Herdr: --split/--workspace/--tab nao tem
equivalente no `terminal create` do Orca (avisamos em stderr e seguimos), e o
Orca nao expoe contador de tokens — `tokens` faz o mesmo parse da TUI.
EOF
}

# ─────────────────── resolução do executável (defensiva) ───────────────────
ORCA_CMD=()

resolve_orca_cmd() {
    [[ ${#ORCA_CMD[@]} -gt 0 ]] && return 0
    local path

    # 1) exportado pelo próprio Orca (sessões gerenciadas, WSL). Pode conter
    #    argumentos, por isso vira array.
    if [[ -n "${ORCA_CLI_COMMAND:-}" ]]; then
        read -r -a ORCA_CMD <<< "$ORCA_CLI_COMMAND"
        return 0
    fi
    # 2) checkout de desenvolvimento do próprio Orca
    if [[ -n "${ORCA_DEV_REPO_ROOT:-}" ]] && command -v orca-dev >/dev/null 2>&1; then
        ORCA_CMD=(orca-dev)
        return 0
    fi
    # 3) nome sem ambiguidade em qualquer shell
    if command -v orca-ide >/dev/null 2>&1; then
        ORCA_CMD=(orca-ide)
        return 0
    fi
    # 4) `orca` cru — só quando comprovadamente NÃO é o leitor de tela do GNOME,
    #    que vive em /usr/bin/orca (/bin é symlink de /usr/bin em muitas
    #    distros). Outros caminhos — inclusive /usr/local/bin, onde o Orca de
    #    desenvolvimento instala seu symlink — são aceitos.
    path="$(command -v orca 2>/dev/null || true)"
    case "$path" in
        ""|/usr/bin/orca|/bin/orca) ;;
        *) ORCA_CMD=("$path"); return 0 ;;
    esac
    return 1
}

has_orca() { resolve_orca_cmd; }

require_orca() {
    if ! resolve_orca_cmd; then
        echo "erro: nao encontrei uma CLI do Orca segura para executar." >&2
        echo "  Procurei nesta ordem: \$ORCA_CLI_COMMAND, orca-dev, orca-ide, orca." >&2
        echo "  (\`orca\` cru foi ignorado: no Linux ele costuma ser o leitor de tela do GNOME.)" >&2
        echo "  $INSTALL_HINT" >&2
        echo "  Sem ele, use o fluxo single-pane normal (ex.: /mosk-suggestion)." >&2
        return 1
    fi
    return 0
}

orca_cli() {
    resolve_orca_cmd || return 1
    "${ORCA_CMD[@]}" "$@"
}

# ─────────────────────────── parsing de JSON ───────────────────────────
# O envelope do Orca é {"id":…,"ok":bool,"result":{…}|"error":{…},"_meta":{…}}.
# Os nomes internos podem variar entre versões, então buscamos por chave em vez
# de fixar caminhos — e degradamos sem python3.

_has_py() { command -v python3 >/dev/null 2>&1; }

# _json_bool <raw> <chave-de-topo-ou-aninhada...> — imprime true/false/vazio.
_json_ok() {
    local raw="$1"
    if _has_py; then
        printf '%s' "$raw" | python3 -c 'import sys,json
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
print("true" if d.get("ok") is True else "false")' 2>/dev/null
    else
        printf '%s' "$raw" | grep -qE '"ok"[[:space:]]*:[[:space:]]*true' && echo true || echo false
    fi
}

# Mensagem de erro do envelope (para reportar ao usuário sem inventar texto).
_json_error() {
    local raw="$1"
    if _has_py; then
        printf '%s' "$raw" | python3 -c 'import sys,json
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
e = d.get("error") or {}
if isinstance(e, dict):
    print("; ".join(str(e[k]) for k in ("code","message") if e.get(k)))' 2>/dev/null
    else
        printf '%s' "$raw" | grep -o '"message":"[^"]*"' | head -1 | cut -d'"' -f4
    fi
}

# O app está de pé? Lê result.app.running do `status`.
_json_app_running() {
    local raw="$1"
    if _has_py; then
        printf '%s' "$raw" | python3 -c 'import sys,json
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
r = (d.get("result") or {})
app = r.get("app") or {}
rt = r.get("runtime") or {}
print("true" if (app.get("running") is True or rt.get("reachable") is True) else "false")' 2>/dev/null
    else
        printf '%s' "$raw" | grep -qE '"running"[[:space:]]*:[[:space:]]*true' && echo true || echo false
    fi
}

# Handle de terminal: busca recursiva por "handle"/"terminalHandle",
# preferindo o valor que parece um handle de terminal (term_…).
_handle_from_json() {
    local raw="$1"
    if _has_py; then
        printf '%s' "$raw" | python3 -c 'import sys,json
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
found = []
def walk(n):
    if isinstance(n, dict):
        for k, v in n.items():
            if k in ("handle", "terminalHandle") and isinstance(v, str) and v:
                found.append(v)
            else:
                walk(v)
    elif isinstance(n, list):
        for v in n:
            walk(v)
walk(d)
for v in found:
    if v.startswith("term"):
        print(v); break
else:
    if found: print(found[0])' 2>/dev/null
    else
        printf '%s' "$raw" | grep -o '"handle":"[^"]*"' | head -1 | cut -d'"' -f4
    fi
}

# Texto de um `terminal read`: pega o maior campo textual do envelope
# (text/output/content, ou lines/rows como lista).
_text_from_json() {
    local raw="$1"
    if _has_py; then
        printf '%s' "$raw" | python3 -c 'import sys,json
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
out = []
def as_line(x):
    if isinstance(x, str): return x
    if isinstance(x, dict): return str(x.get("text") or x.get("content") or "")
    return ""
def walk(n):
    if isinstance(n, dict):
        for k, v in n.items():
            if k in ("text", "output", "content") and isinstance(v, str):
                out.append(v)
            elif k in ("lines", "rows") and isinstance(v, list):
                out.append("\n".join(as_line(x) for x in v))
            else:
                walk(v)
    elif isinstance(n, list):
        for v in n:
            walk(v)
walk(d)
sys.stdout.write(max(out, key=len) if out else "")' 2>/dev/null
    else
        printf '%s' "$raw" | sed -E 's/.*"text":"//; s/"[,}].*$//' | sed 's/\\n/\n/g'
    fi
}

# Executa um subcomando do Orca e, em erro do envelope, reporta e falha.
# Usage: _orca_json <descrição> <args...>  → ecoa o JSON cru em stdout
_orca_json() {
    local what="$1"; shift
    local raw
    raw="$(orca_cli "$@" --json 2>&1 || true)"
    if [[ "$(_json_ok "$raw")" != "true" ]]; then
        local msg
        msg="$(_json_error "$raw")"
        echo "erro: $what falhou${msg:+ ($msg)}." >&2
        [[ -z "$msg" ]] && printf '%s\n' "$raw" >&2
        return 1
    fi
    printf '%s' "$raw"
}

# Junta o argv num único --command, citando o que precisa.
_join_command() {
    local out="" a
    for a in "$@"; do
        case "$a" in
            *[\ \"\'\$\`]*) out+=" '${a//\'/\'\\\'\'}'" ;;
            *) out+=" $a" ;;
        esac
    done
    printf '%s' "${out# }"
}

# ─────────────────────────── subcomandos ───────────────────────────

cmd_check() {
    local json=0
    for a in "$@"; do [[ "$a" == "--json" ]] && json=1; done

    if ! resolve_orca_cmd; then
        if [[ "$json" -eq 1 ]]; then
            echo '{"ok":false,"driver":"orca","orca":false,"reason":"orca-not-found","install":"'"$INSTALL_HINT"'"}'
        else
            require_orca || true
        fi
        return 1
    fi

    local raw running=false bin="${ORCA_CMD[*]}"
    raw="$(orca_cli status --json 2>/dev/null || true)"
    [[ "$(_json_ok "$raw")" == "true" && "$(_json_app_running "$raw")" == "true" ]] && running=true

    if [[ "$json" -eq 1 ]]; then
        if [[ "$running" == true ]]; then
            echo "{\"ok\":true,\"driver\":\"orca\",\"orca\":true,\"runtime_running\":true,\"bin\":\"$bin\"}"
        else
            echo "{\"ok\":false,\"driver\":\"orca\",\"orca\":true,\"runtime_running\":false,\"reason\":\"runtime-unavailable\",\"bin\":\"$bin\"}"
        fi
    else
        if [[ "$running" == true ]]; then
            echo "orca: ok (CLI '$bin' presente, runtime rodando)."
        else
            echo "orca: CLI '$bin' presente, mas o runtime do app nao esta acessivel." >&2
            echo "  Abra/reinicie o app Orca e tente de novo." >&2
        fi
    fi
    [[ "$running" == true ]]
}

cmd_tokens() {
    require_orca || return 1
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
    [[ -n "$ceiling" ]] || ceiling="$(context_token_ceiling)"

    local text used over
    text="$(cmd_read "$pane" 2>/dev/null || true)"
    used="$(printf '%s\n' "$text" | extract_tokens)"

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
    require_orca || return 1
    local cwd="" label="claude" focus=0
    local split="" workspace="" tab=""
    local -a argv=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cwd) cwd="$2"; shift 2 ;;
            --label) label="$2"; shift 2 ;;
            --split) split="$2"; shift 2 ;;
            --workspace) workspace="$2"; shift 2 ;;
            --tab) tab="$2"; shift 2 ;;
            --focus) focus=1; shift ;;
            --no-focus) focus=0; shift ;;
            --) shift; argv=("$@"); break ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) echo "argumento inesperado: $1 (use -- antes do argv)" >&2; return 2 ;;
        esac
    done
    [[ -n "$cwd" ]] || { echo "erro: --cwd e obrigatorio." >&2; return 2; }
    [[ ${#argv[@]} -gt 0 ]] || argv=("$label")

    # O `terminal create` do Orca não posiciona o pane: quem decide tab/split é
    # a UI. Avisamos quando algo foi pedido explicitamente, em vez de fingir que
    # foi aplicado.
    for opt in "split:$split" "workspace:$workspace" "tab:$tab"; do
        [[ -n "${opt#*:}" ]] && echo "aviso: --${opt%%:*} nao tem equivalente no Orca; ignorado." >&2
    done

    local -a extra=()
    [[ "$focus" -eq 1 ]] && extra+=(--focus)

    local raw handle
    if ! raw="$(_orca_json "terminal create" terminal create \
        --worktree "path:$cwd" --title "$label" \
        --command "$(_join_command "${argv[@]}")" "${extra[@]}")"; then
        # O seletor por path pode não resolver (cwd fora de um worktree gerido).
        # Se estamos DENTRO desse diretório, `active` é o mesmo alvo.
        [[ "$cwd" != "$PWD" ]] && return 1
        echo "aviso: seletor path: nao resolveu; tentando --worktree active." >&2
        raw="$(_orca_json "terminal create" terminal create \
            --worktree active --title "$label" \
            --command "$(_join_command "${argv[@]}")" "${extra[@]}")" || return 1
    fi

    handle="$(_handle_from_json "$raw")"
    if [[ -z "$handle" ]]; then
        echo "erro: nao consegui obter o handle do terminal criado." >&2
        printf '%s\n' "$raw" >&2
        return 1
    fi
    echo "$handle"
}

cmd_send() {
    require_orca || return 1
    local pane="$1"; shift || true
    local text="$*"
    [[ -n "$pane" && -n "$text" ]] || { echo "erro: uso: send <pane> <text>" >&2; return 2; }
    # `--enter` é atômico aqui: não precisamos do respiro entre texto e Enter
    # que o backend Herdr exige.
    _orca_json "terminal send" terminal send --terminal "$pane" --text "$text" --enter >/dev/null
}

cmd_wait_idle() {
    require_orca || return 1
    local pane="" timeout="120000"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --timeout) timeout="$2"; shift 2 ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) pane="$1"; shift ;;
        esac
    done
    [[ -n "$pane" ]] || { echo "erro: informe o pane_id." >&2; return 2; }
    _orca_json "terminal wait" terminal wait --terminal "$pane" \
        --for tui-idle --timeout-ms "$timeout" >/dev/null
}

cmd_read() {
    require_orca || return 1
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
    [[ -n "$lines" ]] && extra=(--limit "$lines")
    local raw
    raw="$(_orca_json "terminal read" terminal read --terminal "$pane" "${extra[@]}")" || return 1
    _text_from_json "$raw"
}

cmd_close() {
    require_orca || return 1
    local pane="$1"
    [[ -n "$pane" ]] || { echo "erro: informe o pane_id." >&2; return 2; }
    _orca_json "terminal close" terminal close --terminal "$pane" >/dev/null
}

# ───────────── camada nativa de orquestração (opt-in, ADR-0010) ─────────────
# Só existe no backend Orca. Desligada por padrão: exige
# orchestration.orca.native_tasks: true no core-config (ou MOSK_ORCA_NATIVE_TASKS).
# O que ela dá: provenance (taskId/dispatchId verificáveis), preâmbulo de
# lifecycle injetado no worker e espera POR EVENTO em vez de polling de idle.
#
# O que ela NÃO muda: o julgamento continua humano. O `orchestration run` do Orca
# (coordinator loop autônomo) NUNCA é usado aqui — gates são criados por nós e
# resolvidos com a resposta do humano (ADR-0006).

native_tasks_enabled() {
    if [[ -n "${MOSK_ORCA_NATIVE_TASKS:-}" ]]; then
        [[ "$MOSK_ORCA_NATIVE_TASKS" == "true" ]]
        return
    fi
    local cfg val
    cfg="$(core_config_file 2>/dev/null || true)"
    [[ -n "$cfg" && -f "$cfg" ]] || return 1
    val="$(grep -E '^[[:space:]]*native_tasks:' "$cfg" 2>/dev/null | head -1 | sed -E 's/.*:[[:space:]]*//; s/[[:space:]]*#.*//; s/[[:space:]]*$//')"
    [[ "$val" == "true" ]]
}

require_native() {
    if ! native_tasks_enabled; then
        echo "erro: a camada nativa esta desligada." >&2
        echo "  Ligue com orchestration.orca.native_tasks: true no core-config.yaml." >&2
        return 1
    fi
    require_orca
}

# Extrai um id (task/dispatch/gate) do envelope, tolerando variações de nome.
_id_from_json() {
    local raw="$1" want="$2"
    if _has_py; then
        printf '%s' "$raw" | python3 -c 'import sys,json
want = sys.argv[1]
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)
keys = (want + "Id", want + "_id", "id")
found = {}
def walk(n):
    if isinstance(n, dict):
        for k, v in n.items():
            if k in keys and isinstance(v, (str, int)) and str(v):
                found.setdefault(k, str(v))
            walk(v)
    elif isinstance(n, list):
        for v in n: walk(v)
walk(d)
for k in keys:
    if k in found:
        print(found[k]); break' "$want" 2>/dev/null
    else
        printf '%s' "$raw" | grep -oE "\"${want}Id\":\"?[^\",}]*" | head -1 | sed -E 's/.*:"?//'
    fi
}

cmd_native() {
    local json=0
    for a in "$@"; do [[ "$a" == "--json" ]] && json=1; done
    if native_tasks_enabled; then
        [[ "$json" -eq 1 ]] && echo '{"native_tasks":true}' || echo "native_tasks: on"
        return 0
    fi
    [[ "$json" -eq 1 ]] && echo '{"native_tasks":false}' || echo "native_tasks: off"
    return 1
}

cmd_task_create() {
    require_native || return 1
    local spec="" deps="" parent=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --deps) deps="$2"; shift 2 ;;
            --parent) parent="$2"; shift 2 ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) spec="${spec:+$spec }$1"; shift ;;
        esac
    done
    [[ -n "$spec" ]] || { echo "erro: informe o spec da task." >&2; return 2; }
    local -a extra=()
    [[ -n "$deps" ]] && extra+=(--deps "$deps")
    [[ -n "$parent" ]] && extra+=(--parent "$parent")
    local raw
    raw="$(_orca_json "task-create" orchestration task-create --spec "$spec" "${extra[@]}")" || return 1
    local id
    id="$(_id_from_json "$raw" task)"
    [[ -n "$id" ]] || { echo "erro: nao consegui obter o task id." >&2; printf '%s\n' "$raw" >&2; return 1; }
    echo "$id"
}

cmd_dispatch() {
    require_native || return 1
    local task="" pane="" inject=1
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --inject) inject=1; shift ;;
            --no-inject) inject=0; shift ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) if [[ -z "$task" ]]; then task="$1"; else pane="$1"; fi; shift ;;
        esac
    done
    [[ -n "$task" && -n "$pane" ]] || { echo "erro: uso: dispatch <task_id> <pane> [--no-inject]" >&2; return 2; }
    local -a extra=()
    [[ "$inject" -eq 1 ]] && extra+=(--inject)
    local raw
    raw="$(_orca_json "dispatch" orchestration dispatch --task "$task" --to "$pane" "${extra[@]}")" || return 1
    local id
    id="$(_id_from_json "$raw" dispatch)"
    echo "${id:-ok}"
}

cmd_await() {
    require_native || return 1
    local timeout="900000" types="worker_done,escalation,decision_gate"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --timeout|--timeout-ms) timeout="$2"; shift 2 ;;
            --types) types="$2"; shift 2 ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) shift ;;
        esac
    done
    # Janela rolante: um timeout aqui é CHECKPOINT, não falha do worker. Tarefas
    # longas levam 15-60 min; quem decide parar é o humano.
    _orca_json "orchestration check --wait" orchestration check --wait \
        --types "$types" --timeout-ms "$timeout"
}

cmd_task_list() {
    require_native || return 1
    orca_cli orchestration task-list --json "$@" 2>/dev/null
}

cmd_gate_create() {
    require_native || return 1
    local task="" question="" options=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --options) options="$2"; shift 2 ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) if [[ -z "$task" ]]; then task="$1"; else question="${question:+$question }$1"; fi; shift ;;
        esac
    done
    [[ -n "$task" && -n "$question" ]] || { echo "erro: uso: gate-create <task_id> <pergunta> [--options <json_array>]" >&2; return 2; }
    local -a extra=()
    [[ -n "$options" ]] && extra+=(--options "$options")
    local raw
    raw="$(_orca_json "gate-create" orchestration gate-create --task "$task" --question "$question" "${extra[@]}")" || return 1
    local id
    id="$(_id_from_json "$raw" gate)"
    echo "${id:-ok}"
}

cmd_gate_resolve() {
    require_native || return 1
    local gate="$1"; shift || true
    local resolution="$*"
    [[ -n "$gate" && -n "$resolution" ]] || { echo "erro: uso: gate-resolve <gate_id> <resolucao-decidida-pelo-humano>" >&2; return 2; }
    _orca_json "gate-resolve" orchestration gate-resolve --id "$gate" --resolution "$resolution" >/dev/null
}

cmd_managed() {
    require_orca || return 1
    local cwd=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --cwd) cwd="$2"; shift 2 ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) shift ;;
        esac
    done
    # Registro vivo: o terminal list já traz handle, título e worktree.
    # Devolvemos o JSON cru (mesma semântica do backend Herdr).
    if [[ -z "$cwd" ]]; then
        orca_cli terminal list --json 2>/dev/null
    else
        orca_cli terminal list --worktree "path:$cwd" --json 2>/dev/null
    fi
}

# ─────────────────────────── dispatch ───────────────────────────
# Sourcing não executa nada: permite exercitar o parsing de JSON contra
# fixtures sem um runtime do Orca de pé.
[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0

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
    # camada nativa (opt-in)
    native)       shift; cmd_native "$@" ;;
    task-create)  shift; cmd_task_create "$@" ;;
    task-list)    shift; cmd_task_list "$@" ;;
    dispatch)     shift; cmd_dispatch "$@" ;;
    await)        shift; cmd_await "$@" ;;
    gate-create)  shift; cmd_gate_create "$@" ;;
    gate-resolve) shift; cmd_gate_resolve "$@" ;;
    *) echo "subcomando desconhecido: $1" >&2; usage; exit 2 ;;
esac
