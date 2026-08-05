#!/usr/bin/env bash
# orca.sh — driver do atuador de panes sobre o Orca (onorca.dev), único backend
# suportado (ADR-0014). Implementa o contrato de subcomandos que o /mosk-orq
# conhece, sempre atrás da fachada panes.sh. NUNCA decide o pipeline — o cérebro
# é legal_moves.sh / pipeline-graph.yaml, e o humano decide toda bifurcação
# (ADR-0006/0012).
#
# Wrapper FINO por decisão de arquitetura (ADR-0014 §6): a grammar do Orca não é
# memorizada aqui nem no prompt — o guia é servido pelo binário
# (`orca skills get orchestration`) para evitar version drift.
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

Camada nativa de orquestracao (orchestration.orca.native_tasks: auto|on|off;
default `auto` — liga quando o app expoe a camada):
  native [--json]                         a camada esta ativa? (exit 0 = sim)
  run [<objetivo>] [--json]               cria/vincula a Run (toda Task exige uma)
  task-create <spec> [--deps <json_array>] [--parent <id>] [--objective <t>]
                                          vincula a Run e cria a task; imprime o id
  task-list [--json] [...]                estado das tasks (prova de provenance)
  dispatch <task_id> <pane> [--no-inject] despacha; imprime o dispatch_id
  worker-start --task <id> [--worktree current] [--agent claude] [--name <n>]
        [--retry-of <dispatch_id>]        caminho supervisionado composto (preferido)
  worker-read --dispatch <id> [--limit N] transcript tipado do worker
  await [--timeout-ms <n>] [--types <a,b>] [--ack <delivery_id>]
                                          espera worker_done/escalation/question/gate
  delivery-id                             (stdin: envelope do await) imprime o id
                                          para o --ack da rodada seguinte
  ask <pergunta> [--options <csv>] [--timeout-ms <n>] | --resume <message_id>
                                          worker pergunta e BLOQUEIA
  reply <message_id> <resposta>           coordenador responde a um `ask`
  gate-create <task_id> <pergunta> [--options <json_array>]
                                          abre o decision gate; imprime o gate_id
  gate-resolve <gate_id> <resolucao>      registra a decisao DO HUMANO

Duas armadilhas que custaram bug e estao codificadas acima:
  - `await` SEM --ack reentrega o mesmo lote a cada janela; passe o delivery-id
    da rodada anterior.
  - `question` faz parte dos tipos default: sem ele, um worker que usa `ask`
    fica bloqueado ate o timeout, perguntando para quem nao ouve.

Opcoes globais:
  --help,-h   esta ajuda

O "pane" aqui e o handle de terminal do Orca (term_...). Prefira chamar via
panes.sh, que resolve a disponibilidade do atuador e delega.

Resolucao do executavel (nesta ordem): $ORCA_CLI_COMMAND, orca-dev (quando
$ORCA_DEV_REPO_ROOT), orca-ide, e por fim `orca` — este ultimo APENAS se nao
for /usr/bin/orca (leitor de tela do GNOME).

Config: o teto de tokens padrao vem de core-config.yaml
(orchestration.context_token_ceiling); fallback 800000. Override por --ceiling
ou pela env MOSK_CONTEXT_TOKEN_CEILING.

Limites conhecidos: --split/--workspace/--tab nao tem equivalente no
`terminal create` do Orca (avisamos em stderr e seguimos), e o Orca nao expoe
contador de tokens — `tokens` faz parse da TUI (`over=unknown` quando nao casa).
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
        read -r -a _cand <<< "$ORCA_CLI_COMMAND"
        # QA-010-006: aceitar sem verificar fazia um caminho quebrado falhar mais
        # adiante, no `status`, e ser reportado como `runtime-unavailable` — o
        # usuário lia "abra ou reinicie o app" quando a causa era o caminho não
        # existir. Diagnóstico errado manda consertar a coisa errada.
        if command -v "${_cand[0]}" >/dev/null 2>&1; then
            ORCA_CMD=("${_cand[@]}")
            return 0
        fi
        echo "aviso: \$ORCA_CLI_COMMAND aponta para '${_cand[0]}', que nao e executavel." >&2
        echo "  Ignorando e seguindo para a resolucao normal (orca-dev/orca-ide/orca)." >&2
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

# python3 UTILIZÁVEL, não apenas presente. No macOS sem Command Line Tools existe
# um stub `python3` que só oferece instalar o CLT: `command -v` o encontra, o
# heredoc falha, o `2>/dev/null` engole o erro e o extrator devolve vazio. Sondamos
# uma vez e cacheamos.
# MOSK_ORCA_NO_PY=1 força o ramo de degradação — é como o selftest o alcança numa
# máquina que tem python3. Variável de ambiente de teste, não flag de subcomando.
_has_py() {
    [[ -n "${MOSK_ORCA_NO_PY:-}" ]] && return 1
    if [[ -z "${_MOSK_PY_OK:-}" ]]; then
        if command -v python3 >/dev/null 2>&1 && python3 -c 'pass' >/dev/null 2>&1; then
            _MOSK_PY_OK=yes
        else
            _MOSK_PY_OK=no
        fi
    fi
    [[ "$_MOSK_PY_OK" == yes ]]
}

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
# Extrai o texto do terminal de um envelope do Orca.
#
# Precedência DECLARADA, primeiro match vence. A versão anterior colhia todo campo
# textual do envelope e devolvia `max(out, key=len)` — o mais LONGO ganhava, então
# qualquer campo grande vencia o conteúdo do terminal. Pior: desconhecia `tail`, a
# chave onde o `orca terminal read` entrega a saída, e devolvia string vazia com
# exit 0 (spec 009, achado 1).
_text_from_json() {
    local raw="$1"
    if _has_py; then
        printf '%s' "$raw" | python3 -c 'import sys,json
try: d = json.load(sys.stdin)
except Exception: sys.exit(0)

def as_line(x):
    if isinstance(x, str): return x
    if isinstance(x, dict): return str(x.get("text") or x.get("content") or "")
    return ""

def find_key(root, key, kind):
    hit = []
    def walk(n):
        if hit: return
        if isinstance(n, dict):
            for k, v in n.items():
                if hit: return
                if k == key and isinstance(v, kind):
                    hit.append(v); return
                walk(v)
        elif isinstance(n, list):
            for v in n:
                if hit: return
                walk(v)
    walk(root)
    return hit[0] if hit else None

# 1) caminho conhecido — contrato de fato do `orca terminal read`.
n = d
for p in ("result", "terminal", "tail"):
    n = n.get(p) if isinstance(n, dict) else None
if isinstance(n, list):
    sys.stdout.write("\n".join(as_line(x) for x in n)); sys.exit(0)

# 2) chaves de LISTA, na ordem declarada. Lista vazia é conteúdo vazio legítimo.
for k in ("tail", "lines", "rows"):
    v = find_key(d, k, list)
    if v is not None:
        sys.stdout.write("\n".join(as_line(x) for x in v)); sys.exit(0)

# 3) chaves de STRING, na ordem declarada.
for k in ("text", "output", "content"):
    v = find_key(d, k, str)
    if v is not None:
        sys.stdout.write(v); sys.exit(0)
' 2>/dev/null
    else
        # Sem python3 utilizável, FALHAMOS — não tentamos parsear JSON com sed.
        # O extrator sed anterior (`s/.*"text":"//`) era desancorado: quando a chave
        # não existia, a linha inteira passava adiante e o segundo corte devolvia um
        # fragmento do envelope (`{"id":"x`). Isso é pior que vazio, porque passa por
        # qualquer checagem de "veio conteúdo?".
        # E não há extrator sed honesto aqui: a saída de terminal contém colchetes
        # (barras de progresso, ANSI) que quebram qualquer casamento de array.
        echo "erro: sem python3 utilizável; não é possível parsear a resposta do Orca com segurança." >&2
        echo "  Instale python3. (Um extrator sed corromperia a saída — ver spec 009.)" >&2
        return 1
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

_ms_to_s() { printf '%d.%03d' $(( $1 / 1000 )) $(( $1 % 1000 )); }

# Colapsa espaços em branco (inclusive quebras de linha) para comparar texto que
# passou por uma TUI — ela reflui, alinha e quebra o que recebe.
_normalize_ws() { printf '%s' "$1" | tr '\n\t' '  ' | tr -s ' '; }

# Quantas vezes <needle> aparece em <haystack>. Bash puro: casamento literal por
# construção (a needle entre aspas dentro do padrão não é interpretada), sem
# regex, sem subprocesso, e imune a bytes inválidos que fariam `grep` reclamar.
_count_occurrences() {
    local haystack="$1" needle="$2" n=0 rest="$1"
    [[ -z "$needle" ]] && { echo 0; return 0; }
    while [[ "$rest" == *"$needle"* ]]; do
        rest="${rest#*"$needle"}"
        n=$(( n + 1 ))
    done
    echo "$n"
}

# Confirmação de entrega. Duas forças, e a diferença é o ponto:
#
#   FORTE (padrão): exige que a sonda do texto enviado apareça MAIS VEZES no depois
#   do que no antes. "O terminal mudou" não é prova de nada — a TUI do Claude muda
#   sozinha (spinner, contador de tokens, medidor de compactação), e uma pane
#   recém-spawnada, justo o caso que esta correção existe para pegar, é a que muda
#   mais por conta própria. Confirmar por mudança aceitava entrega perdida como
#   bem-sucedida (QA-009-001, reproduzido).
#
#   FRACA: só quando a sonda é curta demais para ser distintiva (ex.: um `y` de
#   prompt de confiança). Cai para "mudou?" e AVISA que a confirmação é fraca.
#
# Contamos ocorrências em vez de "apareceu?" para que reenviar o MESMO texto ainda
# conte como entrega nova.
#
# Falso negativo é o lado seguro desta troca: o `orq.md` manda reler antes de
# reinjetar, então um "não confirmado" que na verdade chegou custa uma leitura. Um
# falso positivo custa uma fase inteira do pipeline, em silêncio.
_delivery_confirmed() {
    local before="$1" after="$2" sent="${3:-}"
    local floor="${MOSK_SEND_PROBE_MIN:-8}" max="${MOSK_SEND_PROBE_LEN:-24}"
    local nsent; nsent="$(_normalize_ws "$sent")"

    # Até 3 caracteres não há o que sondar (o `y` de um prompt de confiança).
    if (( ${#nsent} <= 3 )); then
        [[ -n "$sent" ]] && \
            echo "aviso: texto curto demais para sondar; confirmação fraca (só mudança de tela)." >&2
        [[ "$after" != "$before" ]]
        return
    fi

    # A TUI NÃO ecoa verbatim — ela reformata. Um `/mosk-dev implement …` pode
    # aparecer como só o token do comando (`⏺ Unknown command: /mosk-dev`), e um
    # prefixo fixo de 24 caracteres dava falso negativo justamente no formato que
    # o `orq.md` mais injeta (QA-009-006). Tentamos candidatas da mais distintiva
    # para a menos, e basta uma incrementar.
    local -a cands
    if (( ${#nsent} < floor )); then
        cands=("$nsent")                       # texto curto: só ele inteiro serve
    else
        (( max > ${#nsent} )) && max=${#nsent}
        cands=("${nsent:0:max}" "${nsent%% *}" "${nsent:0:16}" "${nsent:0:floor}")
    fi

    local minlen="$floor"
    (( minlen > ${#nsent} )) && minlen=${#nsent}

    local nbefore nafter probe seen=""
    nbefore="$(_normalize_ws "$before")"
    nafter="$(_normalize_ws "$after")"
    for probe in "${cands[@]}"; do
        (( ${#probe} < minlen )) && continue
        [[ "$seen" == *"<$probe>"* ]] && continue   # dedup entre candidatas iguais
        seen+="<$probe>"
        (( $(_count_occurrences "$nafter" "$probe") > $(_count_occurrences "$nbefore" "$probe") )) \
            && return 0
    done
    return 1
}

cmd_send() {
    require_orca || return 1
    local pane="$1"; shift || true
    local text="$*"
    [[ -n "$pane" && -n "$text" ]] || { echo "erro: uso: send <pane> <text>" >&2; return 2; }

    # Snapshot ANTES da injeção — a confirmação compara contra ele.
    local before rc=0
    before="$(cmd_read "$pane" 2>/dev/null)" || rc=$?

    # `--enter` é atômico aqui: texto e Enter numa chamada só, sem respiro entre
    # os dois.
    _orca_json "terminal send" terminal send --terminal "$pane" --text "$text" --enter >/dev/null

    # Não conseguir LER é diferente de ler e nada mudar. Sem leitura não há
    # confirmação possível: degradamos para o comportamento antigo, mas avisando —
    # nunca em silêncio.
    if (( rc != 0 )); then
        echo "aviso: pane ilegível; injeção feita SEM confirmação de entrega." >&2
        return 0
    fi

    # Confirmação (spec 009, achado 2): `exit 0` do `terminal send` não prova
    # entrega. Numa TUI ainda montando a interface o texto é descartado e o send
    # reporta sucesso — foi o que custou uma fase inteira de pipeline.
    # Backoff progressivo: o caminho de FALHA é o que roda o laço inteiro, e cada
    # volta é um processo `orca` novo. Passo dobrando (150→800ms) corta as
    # invocações do pior caso pela metade e ainda chega mais rápido no caso bom.
    local deadline_ms="${MOSK_SEND_CONFIRM_MS:-3000}"
    local waited=0 step=150 after=""
    while (( waited < deadline_ms )); do
        sleep "$(_ms_to_s "$step")"
        waited=$(( waited + step ))
        after="$(cmd_read "$pane" 2>/dev/null)" || continue
        _delivery_confirmed "$before" "$after" "$text" && return 0
        (( step < 800 )) && step=$(( step * 2 ))
    done

    echo "erro: entrega não confirmada em ${deadline_ms}ms — o texto injetado não apareceu no terminal." >&2
    echo "  NÃO reinjete às cegas: o \`terminal send\` já executou, e reenviar entrega o" >&2
    echo "  prompt duas vezes. Releia o pane primeiro para separar 'não chegou' de" >&2
    echo "  'chegou devagar' (ver orq.md, Step 2)." >&2
    return 1
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

# ───────────── camada nativa de orquestração (ADR-0010/0013/0014) ─────────────
# Default `auto` desde o ADR-0014 §4: liga quando o app expõe a camada. Sem ela
# não existe Tier 1 de fan-out (ADR-0013), e o /mosk-orq perde ask/reply e gates.
# O que ela dá: provenance (taskId/dispatchId verificáveis), preâmbulo de
# lifecycle injetado no worker e espera POR EVENTO em vez de polling de idle.
#
# O que ela NÃO muda: o julgamento continua humano. O `orchestration run` do Orca
# (coordinator loop autônomo) NUNCA é usado aqui — gates são criados por nós e
# resolvidos com a resposta do humano (ADR-0006/0012).
#
# Modelo do Orca: Run (namespace + inbox do coordenador) → Task (item de
# trabalho, com --deps formando DAG) → Dispatch (uma tentativa numa terminal).
# A autoridade de lifecycle vive no Dispatch, não no terminal.

# A camada de orquestração é uma feature EXPERIMENTAL do app Orca: pode estar
# desligada nas configurações mesmo com o runtime rodando. Sondamos a capacidade
# real em vez de assumir — um comando barato e somente-leitura.
# Motivo de existir: com `native_tasks: auto` (default desde o ADR-0014 §4),
# ligar sem sondar produziria falha no meio de uma onda, não no começo.
#
# A sonda precisa ser um comando SEM pré-condição de estado. `task-list` não
# serve: ele exige uma Run vinculada e responde `run_required` quando não há —
# uma falha que prova justamente o contrário do que se quer medir (a camada
# respondeu!). `run-list` é inspeção pura: não consome mail, não exige Run.
NATIVE_PROBE_CACHE=""
orch_capable() {
    if [[ -z "$NATIVE_PROBE_CACHE" ]]; then
        local raw
        raw="$(orca_cli orchestration run-list --json 2>/dev/null || true)"
        if [[ "$(_json_ok "$raw")" == "true" ]]; then
            NATIVE_PROBE_CACHE=yes
        else
            NATIVE_PROBE_CACHE=no
        fi
    fi
    [[ "$NATIVE_PROBE_CACHE" == yes ]]
}

# on | off | auto (default). Precedência: env > core-config > auto.
# Legado: `true`/`false` continuam válidos como sinônimos de on/off.
NATIVE_REASON=""
native_tasks_enabled() {
    local val="${MOSK_ORCA_NATIVE_TASKS:-}"
    local src="env"
    if [[ -z "$val" ]]; then
        local cfg
        cfg="$(core_config_file 2>/dev/null || true)"
        if [[ -n "$cfg" && -f "$cfg" ]]; then
            val="$(grep -E '^[[:space:]]*native_tasks:' "$cfg" 2>/dev/null | head -1 | sed -E 's/.*:[[:space:]]*//; s/[[:space:]]*#.*//; s/[[:space:]]*$//')"
            src="core-config"
        fi
    fi
    [[ -z "$val" ]] && { val=auto; src=default; }

    case "$val" in
        on|true)
            NATIVE_REASON="ligada explicitamente em $src"
            return 0
            ;;
        off|false)
            NATIVE_REASON="desligada explicitamente em $src"
            return 1
            ;;
        auto)
            if orch_capable; then
                NATIVE_REASON="auto: o app expoe a camada de orquestracao"
                return 0
            fi
            NATIVE_REASON="auto: a orquestracao do app nao respondeu (feature experimental desligada?)"
            return 1
            ;;
        *)
            NATIVE_REASON="valor '$val' desconhecido em $src; tratando como off"
            return 1
            ;;
    esac
}

require_native() {
    if ! native_tasks_enabled; then
        echo "erro: a camada nativa esta indisponivel — $NATIVE_REASON." >&2
        echo "  Se a orquestracao do app estiver desligada, habilite-a em" >&2
        echo "  Settings > Experimental; para forcar, use" >&2
        echo "  orchestration.orca.native_tasks: on no core-config.yaml." >&2
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
def walk(n, depth=0):
    if isinstance(n, dict):
        for k, v in n.items():
            # O `id` da RAIZ do envelope identifica a requisicao, nao o recurso.
            # Aceita-lo como fallback devolvia esse id sempre que a chave
            # especifica faltasse — silenciosamente errado, e a guarda
            # `[[ -n "$id" ]]` de quem chama nunca disparava.
            if k == "id" and depth == 0:
                walk(v, depth + 1)
                continue
            if k in keys and isinstance(v, (str, int)) and str(v):
                found.setdefault(k, str(v))
            walk(v, depth + 1)
    elif isinstance(n, list):
        for v in n: walk(v, depth + 1)
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
        if [[ "$json" -eq 1 ]]; then
            echo "{\"native_tasks\":true,\"reason\":\"$NATIVE_REASON\"}"
        else
            echo "native_tasks: on ($NATIVE_REASON)"
        fi
        return 0
    fi
    if [[ "$json" -eq 1 ]]; then
        echo "{\"native_tasks\":false,\"reason\":\"$NATIVE_REASON\"}"
    else
        echo "native_tasks: off ($NATIVE_REASON)"
    fi
    return 1
}

# Toda Task pertence a uma Run: o contrato manda criar ou vincular uma ANTES de
# `task-create`. Sem isso o comando falha com `run_required` e nada é criado.
#
# A checagem é o próprio `task-list`: ele exige Run vinculada, então o envelope
# responde a pergunta "há Run?" sem efeito colateral. (É exatamente por essa
# pré-condição que ele NÃO serve como sonda de capacidade — ver orch_capable.)
ensure_run() {
    local objective="${1:-MOSK pipeline}"
    local raw
    raw="$(orca_cli orchestration task-list --json 2>/dev/null || true)"
    [[ "$(_json_ok "$raw")" == "true" ]] && return 0

    raw="$(_orca_json "run-create" orchestration run-create --objective "$objective")" || return 1
    local id
    id="$(_id_from_json "$raw" run)"
    [[ -n "$id" ]] && echo "run: $id" >&2
    return 0
}

cmd_run() {
    require_native || return 1
    local objective="" json=0
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json) json=1; shift ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) objective="${objective:+$objective }$1"; shift ;;
        esac
    done
    ensure_run "${objective:-MOSK pipeline}" || return 1
    [[ "$json" -eq 1 ]] && echo '{"ok":true,"run":"bound"}' || echo "run vinculada."
}

cmd_task_create() {
    require_native || return 1
    local spec="" deps="" parent="" objective=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --deps) deps="$2"; shift 2 ;;
            --parent) parent="$2"; shift 2 ;;
            --objective) objective="$2"; shift 2 ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) spec="${spec:+$spec }$1"; shift ;;
        esac
    done
    [[ -n "$spec" ]] || { echo "erro: informe o spec da task." >&2; return 2; }
    ensure_run "${objective:-MOSK pipeline}" || return 1
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

# `question` faz parte do default por necessidade, não por completude: quando um
# worker usa `ask`, o que chega é uma mensagem desse tipo. Sem ela na lista, o
# waiter não acorda e o worker fica bloqueado até o timeout — perguntando para
# alguém que não está ouvindo.
AWAIT_DEFAULT_TYPES="worker_done,escalation,question,decision_gate"

cmd_await() {
    require_native || return 1
    local timeout="900000" types="$AWAIT_DEFAULT_TYPES" ack=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --timeout|--timeout-ms) timeout="$2"; shift 2 ;;
            --types) types="$2"; shift 2 ;;
            --ack) ack="$2"; shift 2 ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) shift ;;
        esac
    done
    # O `check` devolve a Delivery FIFO mais antiga e REPETE esse mesmo lote até
    # receber `--ack <delivery_id>`. Sem o ack, cada janela reentrega o que já foi
    # processado e a espera nunca avança. Passe o deliveryId da rodada anterior:
    # `--ack <id>` reconhece, checa e espera numa operação só.
    local -a extra=()
    [[ -n "$ack" ]] && extra+=(--ack "$ack")

    # `check --wait` NÃO devolve um envelope só: enquanto espera, emite uma linha
    # NDJSON de keepalive a cada ~15s —
    #   {"_keepalive":true,"_heartbeat":true,"elapsedMs":...,"deadlineMs":...}
    # — e só ao fim escreve o envelope real (que pode vir pretty-printed em
    # várias linhas). Validar a saída inteira como um JSON único faz TODA espera
    # falhar, mesmo bem-sucedida: foi o defeito QA-010-007, e é por isso que
    # este caminho não passa pelo `_orca_json`.
    #
    # Filtrar as linhas de keepalive (que são sempre single-line) deixa
    # exatamente o envelope — inclusive quando ele é multi-linha.
    local raw
    raw="$(orca_cli orchestration check --wait "${extra[@]}" \
        --types "$types" --timeout-ms "$timeout" --json 2>&1 \
        | grep -v '"_keepalive"' || true)"

    # Janela rolante: um timeout aqui é CHECKPOINT, não falha do worker. Tarefas
    # longas levam 15-60 min; quem decide parar é o humano. Uma espera que
    # termina sem envelope é silêncio, não erro — devolvemos um envelope vazio
    # sintético para o chamador seguir o mesmo caminho de "nada chegou".
    if [[ -z "${raw//[[:space:]]/}" ]]; then
        echo '{"ok":true,"result":{"messages":[],"count":0,"_mosk":"wait-timeout"}}'
        return 0
    fi
    if [[ "$(_json_ok "$raw")" != "true" ]]; then
        local msg
        msg="$(_json_error "$raw")"
        echo "erro: orchestration check --wait falhou${msg:+ ($msg)}." >&2
        [[ -z "$msg" ]] && printf '%s\n' "$raw" >&2
        return 1
    fi
    printf '%s' "$raw"
}

# Extrai o deliveryId do envelope devolvido por `await`, para alimentar o --ack
# da rodada seguinte. Sem isso o chamador teria de parsear JSON no prompt.
cmd_delivery_id() {
    local raw
    raw="$(cat)"
    _id_from_json "$raw" delivery
}

cmd_task_list() {
    require_native || return 1
    orca_cli orchestration task-list --json "$@" 2>/dev/null
}

# ── ask / reply: canal estruturado de pergunta bloqueante ──
# É o par natural dos guards `judgment` e dos blocos "Escalation suggested"
# (ADR-0006): em vez de texto solto num terminal, a dúvida vira uma mensagem
# tipada que acorda o coordenador e recebe resposta rastreável.
#
# `ask` é do WORKER (pergunta e bloqueia). `reply` é do COORDENADOR.
# Timeout NÃO cancela a pergunta: ela fica pendente. Retomar é `ask --resume
# <message_id>` — perguntar de novo criaria uma segunda thread idêntica, e aí não
# há como saber qual resposta pertence a qual pergunta.
cmd_ask() {
    require_native || return 1
    local question="" options="" timeout="600000" resume=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --options) options="$2"; shift 2 ;;
            --timeout|--timeout-ms) timeout="$2"; shift 2 ;;
            --resume) resume="$2"; shift 2 ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) question="${question:+$question }$1"; shift ;;
        esac
    done
    local -a args=()
    if [[ -n "$resume" ]]; then
        args=(--resume "$resume")
    else
        [[ -n "$question" ]] || { echo "erro: informe a pergunta (ou --resume <message_id>)." >&2; return 2; }
        args=(--question "$question")
        [[ -n "$options" ]] && args+=(--options "$options")
    fi
    _orca_json "ask" orchestration ask "${args[@]}" --timeout-ms "$timeout"
}

cmd_reply() {
    require_native || return 1
    local msg="" body=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --id) msg="$2"; shift 2 ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) if [[ -z "$msg" ]]; then msg="$1"; else body="${body:+$body }$1"; fi; shift ;;
        esac
    done
    [[ -n "$msg" && -n "$body" ]] || { echo "erro: uso: reply <message_id> <resposta>" >&2; return 2; }
    _orca_json "reply" orchestration reply --id "$msg" --body "$body" >/dev/null
}

# Espera o buffer do terminal PARAR DE CRESCER antes de submeter.
#
# Existe porque o `worker-start` injeta o prompt de forma assíncrona: `tui-idle`
# retorna com o texto ainda entrando, e um Enter mandado nesse instante se perde
# no meio da injeção — o prompt fica no buffer, o agente nunca processa, e a task
# trava em `dispatched` (QA-010-008). Confirmado empiricamente: os mesmos Enter
# enviados depois, com o texto já completo, submeteram e o worker executou.
#
# É o "respiro" que a spec 009 documentou para o Herdr. O ADR-0010 §2 registrou
# que o `--enter` atômico do Orca o dispensava — verdade para `send`, falso para
# `worker-start`, que não injeta pela mesma via.
_wait_buffer_settled() {
    local handle="$1" tries="${2:-20}" prev="" cur="" stable=0
    local i
    for ((i = 0; i < tries; i++)); do
        cur="$(cmd_read "$handle" 2>/dev/null || true)"
        if [[ -n "$cur" && "$cur" == "$prev" ]]; then
            stable=$((stable + 1))
            # duas leituras idênticas seguidas: injeção terminou.
            [[ "$stable" -ge 2 ]] && return 0
        else
            stable=0
        fi
        prev="$cur"
        sleep 0.5
    done
    echo "aviso: buffer de $handle nao estabilizou; submetendo mesmo assim." >&2
    return 1
}

# ── worker-start: caminho supervisionado composto ──
# Compõe worktree + terminal + readiness + dispatch numa operação e devolve um
# recibo com os efeitos exatos. Preferido ao par spawn-próprio + dispatch
# low-level, que fica para topologia que esta composição não expressa.
#
# `--worktree current` NÃO cria worktree git: cria um terminal de agente novo no
# worktree atual. Criar worktree de verdade só se houver conflito concreto de
# arquivos — paralelismo por si só não é motivo.
cmd_worker_start() {
    require_native || return 1
    local task="" worktree="current" agent="claude" name="" retry_of=""
    local submit=1 submit_timeout=60000
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --task) task="$2"; shift 2 ;;
            --worktree) worktree="$2"; shift 2 ;;
            --agent) agent="$2"; shift 2 ;;
            --name) name="$2"; shift 2 ;;
            --retry-of) retry_of="$2"; shift 2 ;;
            --no-submit) submit=0; shift ;;
            --submit-timeout) submit_timeout="$2"; shift 2 ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) [[ -z "$task" ]] && task="$1"; shift ;;
        esac
    done
    [[ -n "$task" ]] || { echo "erro: uso: worker-start --task <task_id> [--worktree current] [--agent claude]" >&2; return 2; }
    local -a extra=()
    [[ -n "$name" ]] && extra+=(--name "$name")
    [[ -n "$retry_of" ]] && extra+=(--retry-of "$retry_of")
    local raw
    raw="$(_orca_json "worker-start" orchestration worker-start \
        --task "$task" --worktree "$worktree" --agent "$agent" "${extra[@]}")" || return 1
    local id
    id="$(_id_from_json "$raw" dispatch)"

    # QA-010-008: o worker-start cria terminal e dispatch, mas o prompt pode
    # ficar no BUFFER DE INPUT da TUI sem ser submetido — observado com o agente
    # `claude`, que ficou `running` com 0 tokens e o texto visível e não
    # processado, com a task presa em `dispatched`. É a mesma classe de falha que
    # a spec 009 corrigiu para o `send`: entrega sem prova.
    #
    # Mitigação: esperar a TUI ficar pronta e submeter explicitamente. Um Enter
    # com input vazio é no-op quando o prompt JÁ foi submetido, então a operação
    # é segura nos dois casos — e é por isso que ela é incondicional em vez de
    # depender de detectar "não submetido", que não tem sinal genérico confiável.
    if [[ "$submit" -eq 1 ]]; then
        local handle
        handle="$(_handle_from_json "$raw")"
        if [[ -n "$handle" ]]; then
            orca_cli terminal wait --terminal "$handle" --for tui-idle \
                --timeout-ms "$submit_timeout" --json >/dev/null 2>&1 || true
            _wait_buffer_settled "$handle"
            orca_cli terminal send --terminal "$handle" --text "" --enter --json >/dev/null 2>&1 \
                || echo "aviso: nao consegui confirmar a submissao do prompt em $handle." >&2
        else
            echo "aviso: worker-start nao devolveu handle; submissao do prompt NAO confirmada." >&2
        fi
    fi

    echo "${id:-ok}"
}

# ── worker-read: leitura tipada, por dispatch ──
# Devolve o transcript que o Orca consegue provar, ou saída de terminal com
# `fallbackReason` explícito quando não consegue. Prefira isto a `read` de
# terminal cru: foi essa superfície que quebrou em silêncio na spec 009.
# Continue pelo `cursor` devolvido; em `source_changed`, recomece sem o antigo.
cmd_worker_read() {
    require_native || return 1
    local dispatch="" limit="50"
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dispatch) dispatch="$2"; shift 2 ;;
            --limit) limit="$2"; shift 2 ;;
            -*) echo "opcao desconhecida: $1" >&2; return 2 ;;
            *) [[ -z "$dispatch" ]] && dispatch="$1"; shift ;;
        esac
    done
    [[ -n "$dispatch" ]] || { echo "erro: uso: worker-read --dispatch <dispatch_id> [--limit N]" >&2; return 2; }
    _orca_json "worker-read" orchestration worker-read --dispatch "$dispatch" --limit "$limit"
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
    # Devolvemos o JSON cru: quem chama filtra o que precisa.
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
    # camada nativa de orquestração (native_tasks: auto)
    native)       shift; cmd_native "$@" ;;
    run)          shift; cmd_run "$@" ;;
    task-create)  shift; cmd_task_create "$@" ;;
    task-list)    shift; cmd_task_list "$@" ;;
    dispatch)     shift; cmd_dispatch "$@" ;;
    worker-start) shift; cmd_worker_start "$@" ;;
    worker-read)  shift; cmd_worker_read "$@" ;;
    await)        shift; cmd_await "$@" ;;
    delivery-id)  shift; cmd_delivery_id "$@" ;;
    ask)          shift; cmd_ask "$@" ;;
    reply)        shift; cmd_reply "$@" ;;
    gate-create)  shift; cmd_gate_create "$@" ;;
    gate-resolve) shift; cmd_gate_resolve "$@" ;;
    *) echo "subcomando desconhecido: $1" >&2; usage; exit 2 ;;
esac
