#!/usr/bin/env bash
# selftest-orca-driver.sh — exercita o parsing do driver Orca contra envelopes
# FIXTURE, sem app Orca de pé.
#
# Por que existe: o achado 1 da spec 009 (o `read` devolvendo string vazia porque
# `_text_from_json` desconhecia a chave `tail`) shipou justamente porque não havia
# como rodar o extrator offline. O `orca.sh` já era sourceável sem executar nada —
# faltava alguém escrever as fixtures.
#
# Cobre: precedência de chaves, lista vazia como conteúdo legítimo, envelope de
# erro, ramo de degradação sem python3, o predicado de confirmação de entrega,
# os tipos default da espera (`question` presente), a extração do deliveryId que
# alimenta o `--ack`, a resolução de `native_tasks`, e as duas regras de
# numeração de spec.
#
# Usage: selftest-orca-driver.sh [--verbose] [--help]
# Exit 0 = tudo passou; exit 1 = falhas listadas (caso :: esperado :: obtido).
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

VERBOSE=0
for arg in "$@"; do
    case "$arg" in
        --help|-h) sed -n '2,14p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        --verbose|-v) VERBOSE=1 ;;
        *) echo "opcao desconhecida: $arg" >&2; exit 2 ;;
    esac
done

# shellcheck source=/dev/null
source "$SCRIPT_DIR/orca.sh"
# orca.sh traz `set -e`; aqui queremos rodar TODOS os casos e só então reportar.
set +e

PASS=0
FAILURES=""

ok()   { PASS=$((PASS + 1)); [[ "$VERBOSE" -eq 1 ]] && echo "  ok   $1"; return 0; }
fail() { FAILURES+="  $1"$'\n    esperado: '"$2"$'\n    obtido:   '"$3"$'\n'; }

check_eq() {
    local name="$1" expected="$2" got="$3"
    if [[ "$got" == "$expected" ]]; then ok "$name"; else fail "$name" "$expected" "$got"; fi
}

# ─────────────────────────── fixtures ───────────────────────────
# Envelope real do `orca terminal read`. Note os colchetes na barra de progresso:
# é por isso que não existe extrator sed honesto para este formato.
FX_TAIL='{"id":"x","ok":true,"result":{"terminal":{"handle":"term_x","status":"running","tail":["❯","  ➜ cfo-skills git:(001-feature)…","  compact [████████░░] 85%"],"truncated":false,"returnedLineCount":3}}}'

FX_TAIL_EMPTY='{"id":"x","ok":true,"result":{"terminal":{"handle":"term_x","status":"running","tail":[],"returnedLineCount":0}}}'

FX_ERROR='{"id":"x","ok":false,"error":{"code":"terminal_handle_stale","message":"handle no longer valid"}}'

# `tail` curto competindo com um campo textual MUITO mais longo em outro ramo.
# A regra antiga (max(out, key=len)) devolvia o campo longo; a nova devolve o tail.
FX_TAIL_VS_LONG='{"id":"x","ok":true,"meta":{"content":"AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA"},"result":{"terminal":{"handle":"term_x","tail":["short"]}}}'

FX_TAIL_DICTS='{"id":"x","ok":true,"result":{"terminal":{"handle":"term_x","tail":[{"text":"linha um"},{"content":"linha dois"}]}}}'

FX_LINES_ONLY='{"id":"x","ok":true,"result":{"terminal":{"handle":"term_x","lines":["via lines"]}}}'

echo "selftest-orca-driver: extrator de texto"

# ── caso 1: tail populado ──
EXPECTED_1='❯
  ➜ cfo-skills git:(001-feature)…
  compact [████████░░] 85%'
check_eq "1. tail com 3 linhas" "$EXPECTED_1" "$(_text_from_json "$FX_TAIL")"

# ── caso 2: tail vazio é conteúdo vazio LEGÍTIMO, não erro ──
got="$(_text_from_json "$FX_TAIL_EMPTY")"; rc=$?
check_eq "2a. tail vazio devolve string vazia" "" "$got"
check_eq "2b. tail vazio sai com exit 0" "0" "$rc"

# ── caso 3: envelope de erro é barrado antes do extrator, por _json_ok ──
check_eq "3a. _json_ok reprova envelope de erro" "false" "$(_json_ok "$FX_ERROR")"
check_eq "3b. _json_ok aprova envelope bom" "true" "$(_json_ok "$FX_TAIL")"
check_eq "3c. _json_error extrai a mensagem" "terminal_handle_stale; handle no longer valid" "$(_json_error "$FX_ERROR")"

# ── caso 4: precedência por SEMÂNTICA, não por comprimento ──
check_eq "4. tail curto vence campo textual longo" "short" "$(_text_from_json "$FX_TAIL_VS_LONG")"

# ── caso 5: itens dict dentro de tail ──
EXPECTED_5='linha um
linha dois'
check_eq "5. tail com itens dict" "$EXPECTED_5" "$(_text_from_json "$FX_TAIL_DICTS")"

# ── caso 5b: fallback de chave (lines) segue funcionando ──
check_eq "5b. cai para 'lines' quando não há tail" "via lines" "$(_text_from_json "$FX_LINES_ONLY")"

# ── caso 6: ramo de degradação sem python3 ──
# Regra: falhar explicitamente. NUNCA devolver fragmento do envelope — o extrator
# sed anterior devolvia `{"id":"x` aqui, que passa por qualquer checagem de
# "veio conteúdo?" e envenena quem consome (ex.: extract_tokens).
echo "selftest-orca-driver: ramo sem python3 (MOSK_ORCA_NO_PY=1)"
unset _MOSK_PY_OK
for fx_name in FX_TAIL FX_TAIL_EMPTY FX_ERROR FX_TAIL_VS_LONG; do
    got="$(MOSK_ORCA_NO_PY=1 _MOSK_PY_OK="" _text_from_json "${!fx_name}" 2>/dev/null)"
    rc=$?
    check_eq "6. $fx_name: sem python3 não emite stdout" "" "$got"
    if (( rc != 0 )); then ok "6. $fx_name: sem python3 falha explicitamente (exit $rc)"
    else fail "6. $fx_name: sem python3 deve falhar" "exit != 0" "exit 0"; fi
done
unset _MOSK_PY_OK

# ── caso 7: predicado de confirmação de entrega ──
# O 7d é a regressão que motivou o QA-009-001: mudança de tela NÃO é prova de
# entrega. A TUI do Claude muda sozinha (spinner, contador de tokens, medidor de
# compactação), então aceitar "mudou" confirmava entrega perdida.
echo "selftest-orca-driver: predicado de confirmação de entrega"

want_confirmed() {   # nome, before, after, sent
    if _delivery_confirmed "$2" "$3" "$4" 2>/dev/null; then ok "$1"
    else fail "$1" "confirmado" "não confirmado"; fi
}
want_rejected() {    # nome, before, after, sent
    if _delivery_confirmed "$2" "$3" "$4" 2>/dev/null; then fail "$1" "não confirmado" "confirmado"
    else ok "$1"; fi
}

SENT="/mosk-dev implement a fase 3 da spec 009"

want_confirmed "7a. texto enviado aparece no depois → confirmado" \
    "❯" "❯ $SENT" "$SENT"
want_rejected  "7b. nada mudou → não confirmado" \
    "❯ prompt" "❯ prompt" "$SENT"
want_rejected  "7c. vazio antes e depois → não confirmado" \
    "" "" "$SENT"

# ↓ a regressão do QA-009-001
want_rejected  "7d. MUDOU mas sem o texto → não confirmado" \
    "✻ Crunched for 2s · 100 tokens" "✻ Wrangling… · 257 tokens · compact [██░░] 20%" "$SENT"

want_confirmed "7e. reenvio do mesmo texto (2ª ocorrência) → confirmado" \
    "❯ $SENT" "❯ $SENT
❯ $SENT" "$SENT"
want_confirmed "7f. TUI quebrou a linha no meio do texto → confirmado" \
    "❯" "❯ /mosk-dev implement a fase
  3 da spec 009" "$SENT"
want_rejected  "7g. texto com metacaractere não é tratado como regex" \
    "❯" "❯ literal a.c aqui" 'a[b]c'
want_confirmed "7h. texto curto (y) → modo fraco: mudança confirma" \
    "prompt?" "prompt? y" "y"
want_rejected  "7i. texto curto (y) sem mudança → não confirmado" \
    "prompt?" "prompt?" "y"

# ── caso 7j–7m: a TUI reformata o eco (QA-009-006) ──
# Eco parcial REAL capturado pelo QA: enviamos comando + argumento, a TUI mostrou
# só o token do comando. Exigir prefixo fixo de 24 dava falso negativo no formato
# que o orq.md mais injeta.
want_confirmed "7j. TUI ecoou só o token do comando (eco real do QA) → confirmado" \
    "❯" "⏺ Unknown command: /mosk-zzz-probe-009" "/mosk-zzz-probe-009 teste de sonda"
want_confirmed "7k. slash command com argumento longo, eco só do comando → confirmado" \
    "❯" "❯ /mosk-dev" "/mosk-dev implement a fase 3 da spec 009"
# O afrouxamento não pode virar porta dos fundos: agente DIFERENTE não confirma.
want_rejected  "7l. eco de outro agente (/mosk-qa) não confirma envio de /mosk-dev" \
    "❯" "❯ /mosk-qa qa-gate" "/mosk-dev implement a fase 3 da spec 009"
want_rejected  "7m. só o prefixo comum /mosk- não basta para confirmar" \
    "❯" "❯ /mosk-" "/mosk-dev implement a fase 3 da spec 009"

# ── caso 8: dependência de caminho do common.sh, em bash E zsh ──
# O driver sourceia common.sh. Se a resolução de caminho lá quebra em zsh (onde
# BASH_SOURCE não existe), o driver herda o problema — e as tasks do MOSK mandam o
# agente sourcear common.sh no shell dele, que no macOS é zsh.
echo "selftest-orca-driver: resolução de caminho do common.sh (bash vs zsh)"
for shell_bin in bash zsh; do
    if ! command -v "$shell_bin" >/dev/null 2>&1; then
        [[ "$VERBOSE" -eq 1 ]] && echo "  skip $shell_bin (ausente)"
        continue
    fi
    got="$("$shell_bin" -c "source '$SCRIPT_DIR/common.sh' 2>/dev/null; graph_edge_exists specify plan && echo TRUE || echo FALSE" 2>/dev/null)"
    check_eq "8. $shell_bin: graph_edge_exists specify plan" "TRUE" "$got"
    got="$("$shell_bin" -c "source '$SCRIPT_DIR/common.sh' 2>/dev/null; graph_edge_exists specify implement && echo TRUE || echo FALSE" 2>/dev/null)"
    check_eq "8. $shell_bin: aresta inexistente segue reprovada" "FALSE" "$got"
done

# ── caso 9: `question` entre os tipos que despertam a espera (spec 010) ──
# Sem ele na lista default, um worker que usa `ask` fica bloqueado até o timeout,
# perguntando para um coordenador que não está ouvindo. Foi um defeito real.
echo "selftest-orca-driver: tipos default da espera"
case "$AWAIT_DEFAULT_TYPES" in
    *question*) ok "9. question esta nos tipos default" ;;
    *) fail "9. question esta nos tipos default" "conter 'question'" "$AWAIT_DEFAULT_TYPES" ;;
esac
case "$AWAIT_DEFAULT_TYPES" in
    *worker_done*) ok "9. worker_done segue nos tipos default" ;;
    *) fail "9. worker_done segue nos tipos default" "conter 'worker_done'" "$AWAIT_DEFAULT_TYPES" ;;
esac

# ── caso 10: extração do deliveryId, que alimenta o --ack da rodada seguinte ──
# Sem o ack, cada janela de espera reentrega o mesmo lote FIFO e a supervisão
# nunca avança. O id precisa sair do envelope de forma confiável.
echo "selftest-orca-driver: deliveryId para o --ack"
FX_DELIVERY='{"id":"x","ok":true,"result":{"deliveryId":"dlv_123","count":2,"messages":[{"type":"worker_done"}]}}'
FX_NO_DELIVERY='{"id":"x","ok":true,"result":{"count":0,"messages":[]}}'
check_eq "10. deliveryId extraido do envelope" "dlv_123" "$(_id_from_json "$FX_DELIVERY" delivery)"
check_eq "10. envelope sem delivery nao inventa id" "" "$(_id_from_json "$FX_NO_DELIVERY" delivery)"

# ── caso 11: native_tasks on/off explícito não toca a rede ──
# `auto` sonda o app (e por isso não é testável offline); on/off precisam
# resolver sem nenhuma chamada, para que a config do usuário sempre vença.
echo "selftest-orca-driver: resolucao de native_tasks"
MOSK_ORCA_NATIVE_TASKS=on  native_tasks_enabled && got=TRUE || got=FALSE
check_eq "11. native_tasks=on resolve ligado" "TRUE" "$got"
MOSK_ORCA_NATIVE_TASKS=off native_tasks_enabled && got=TRUE || got=FALSE
check_eq "11. native_tasks=off resolve desligado" "FALSE" "$got"
MOSK_ORCA_NATIVE_TASKS=true native_tasks_enabled && got=TRUE || got=FALSE
check_eq "11. legado 'true' segue valendo" "TRUE" "$got"
unset MOSK_ORCA_NATIVE_TASKS

# ── caso 12: numeração de spec (spec 010, US5) ──
# Estes dois exercitam as REGRAS que o create-new-feature.sh aplica, não o script
# em si — ele executa ao ser sourceado, então não dá para chamar suas funções
# offline. Ainda assim pegam a regressão: se alguém desancorar a regex ou tirar o
# `10#`, o caso quebra aqui, não na próxima spec criada.
echo "selftest-orca-driver: numeracao de spec"
BRANCHES=$'015-feature-graph-loop-orca\ndocs/adr-0012-0014-x\nfix/issue-123-foo\nchore/rfc-042-bar\nmaster'
got="$(printf '%s\n' "$BRANCHES" | grep -oE '^[0-9]{3}-' | grep -oE '[0-9]+' | sort -n | tr '\n' ',')"
check_eq "12. so o prefixo ancorado conta como spec" "015," "$got"

# ── caso 12b: numeração nos DOIS formatos de branch (spec 011, ADR-0017) ──
# `tipo/NNN-nome` passou a ser o canônico; `NNN-tipo-nome` continua em uso. A
# detecção precisa contar os dois — e a âncora `^` continua sendo o que impede
# que um "NNN-" embutido conte como spec. Alargar a regex sem manter a âncora
# reintroduziria de uma vez o bug que a spec 010 corrigiu.
BRANCHES2=$'011-feature-direct-agents\nfeature/012-algo\nfix/013-bug\nhotfix/014-urgente\ndocs/adr-0012-0014-x\nchore/sync-042-pmo\nfeat/komodo-deploy\nmaster'
got="$(printf '%s\n' "$BRANCHES2" | sed -nE 's|^([a-z][a-z-]*/)?([0-9]{3})-.*|\2|p' | sort -n | tr '\n' ',')"
check_eq "12b. conta os dois formatos, ignora o resto" "011,012,013,014," "$got"

# `chore/sync-042-pmo` NÃO pode contar: o 042 está no meio do nome, não logo
# após a barra. É a distinção que faz "tem número" significar "tem spec".
case "$got" in
    *042*) fail "12b. numero no meio do nome nao conta" "sem 042" "$got" ;;
    *) ok "12b. numero no meio do nome nao conta" ;;
esac

# Resolução branch -> pasta: a pasta é PLANA, o branch tem o tipo à frente.
check_eq "12b. prefixo extraido do formato novo" "012" \
    "$(printf 'feature/012-algo\n' | sed -nE 's|^([a-z][a-z-]*/)?([0-9]{3})-.*|\2|p')"
check_eq "12b. prefixo extraido do formato legado" "011" \
    "$(printf '011-feature-direct-agents\n' | sed -nE 's|^([a-z][a-z-]*/)?([0-9]{3})-.*|\2|p')"
check_eq "12. --number 010 vale dez, nao octal oito" "010" "$(printf '%03d' "$((10#010))")"
check_eq "12. --number 15 normaliza para 015" "015" "$(printf '%03d' "$((10#15))")"

# ── caso 13: NDJSON de keepalive do `check --wait` (QA-010-007) ──
# O `check --wait` emite uma linha de keepalive a cada ~15s e só depois o
# envelope real — que pode vir pretty-printed. Validar a saída inteira como um
# JSON único fazia TODA espera falhar, mesmo bem-sucedida. O filtro precisa
# remover as linhas de keepalive (sempre single-line) e preservar o envelope
# multi-linha intacto.
echo "selftest-orca-driver: NDJSON do check --wait"
FX_WAIT_STREAM='{"_keepalive":true,"_heartbeat":true,"elapsedMs":15003,"deadlineMs":180000}
{"_keepalive":true,"_heartbeat":true,"elapsedMs":30004,"deadlineMs":180000}
{
  "id": "abc",
  "ok": true,
  "result": {
    "deliveryId": "dlv_777",
    "count": 1
  }
}'
filtered="$(printf '%s\n' "$FX_WAIT_STREAM" | grep -v '"_keepalive"')"
check_eq "13. envelope sobrevive ao filtro" "true" "$(_json_ok "$filtered")"
check_eq "13. deliveryId legivel apos o filtro" "dlv_777" "$(_id_from_json "$filtered" delivery)"
check_eq "13. nenhuma linha de keepalive sobra" "0" "$(printf '%s' "$filtered" | grep -c '_keepalive' || true)"

# Espera que termina só com keepalives = silêncio, não erro: o chamador precisa
# distinguir "nada chegou" de "falhou", porque timeout é checkpoint (ADR-0013).
FX_WAIT_ONLY_KEEPALIVE='{"_keepalive":true,"_heartbeat":true,"elapsedMs":15003,"deadlineMs":30000}
{"_keepalive":true,"_heartbeat":true,"elapsedMs":30004,"deadlineMs":30000}'
empty="$(printf '%s\n' "$FX_WAIT_ONLY_KEEPALIVE" | grep -v '"_keepalive"')"
check_eq "13. so keepalive -> resta vazio (timeout, nao erro)" "" "${empty//[[:space:]]/}"

# ─────────────────────────── relatório ───────────────────────────
echo
if [[ -n "$FAILURES" ]]; then
    echo "FALHOU — $PASS asserção(ões) ok, e:"
    printf '%s' "$FAILURES"
    exit 1
fi
echo "OK — $PASS asserções."
